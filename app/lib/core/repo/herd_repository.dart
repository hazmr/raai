import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import '../api/api.dart';
import '../api/models.dart';
import '../db/app_database.dart';
import '../sync/outbox.dart';

/// The herd, read from SQLite and written through the outbox (§7).
///
/// Reads never touch the network: the UI watches the local tables, so the app
/// opens instantly in a barn with no signal. Writes land locally *and* in the
/// outbox, so a note taken at the far end of a field appears in the timeline at
/// once and is delivered when the phone reconnects.
class HerdRepository {
  HerdRepository({required this.db, required this.api});

  final AppDatabase db;
  final HerdApi api;

  static const _uuid = Uuid();

  // --- reads (local only) ---

  /// Watches the herd, newest first. [query] filters by ear tag as you type.
  Stream<List<Animal>> watchAnimals({String query = ''}) {
    final select = db.select(db.cachedAnimals)
      ..orderBy([
        (a) => OrderingTerm(expression: a.createdAt, mode: OrderingMode.desc),
        (a) => OrderingTerm(expression: a.localId, mode: OrderingMode.desc),
      ]);
    if (query.isNotEmpty) {
      select.where((a) => a.barcode.like('%$query%'));
    }
    return select.watch().map((rows) => rows.map(_toAnimal).toList());
  }

  Stream<Animal?> watchAnimal(int localId) {
    return (db.select(db.cachedAnimals)..where((a) => a.localId.equals(localId)))
        .watchSingleOrNull()
        .map((row) => row == null ? null : _toAnimal(row));
  }

  /// Watches one animal's notes, newest first.
  Stream<List<Note>> watchNotes(int animalLocalId) {
    final select = db.select(db.cachedNotes)
      ..where((n) => n.animalLocalId.equals(animalLocalId))
      ..orderBy([
        (n) => OrderingTerm(expression: n.createdAt, mode: OrderingMode.desc),
        (n) => OrderingTerm(expression: n.localId, mode: OrderingMode.desc),
      ]);
    return select.watch().map((rows) => rows.map(_toNote).toList());
  }

  /// Local ear-tag lookup for the scanner — a scan must resolve with no signal.
  Future<Animal?> findByBarcode(String barcode) async {
    final row = await (db.select(db.cachedAnimals)
          ..where((a) => a.barcode.equals(barcode))
          ..limit(1))
        .getSingleOrNull();
    return row == null ? null : _toAnimal(row);
  }

  Future<int> herdCount() async {
    final count = countAll();
    final query = db.selectOnly(db.cachedAnimals)..addColumns([count]);
    return await query.map((row) => row.read(count)!).getSingle();
  }

  // --- writes (local first, then queued) ---

  /// Registers an ear tag locally and queues the create. Returns the local row,
  /// which the caller can navigate to straight away.
  Future<Animal> addAnimal(String barcode) async {
    final existing = await findByBarcode(barcode);
    if (existing != null) return existing;

    return db.transaction(() async {
      final localId = await db.into(db.cachedAnimals).insert(
            CachedAnimalsCompanion.insert(
              barcode: barcode,
              createdAt: DateTime.now(),
              pending: const Value(true),
            ),
          );
      await db.into(db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              kind: OutboxKind.createAnimal.name,
              idempotencyKey: _uuid.v4(),
              targetLocalId: localId,
              payload: jsonEncode({'barcode': barcode}),
              createdAt: DateTime.now(),
            ),
          );
      final row = await (db.select(db.cachedAnimals)
            ..where((a) => a.localId.equals(localId)))
          .getSingle();
      return _toAnimal(row);
    });
  }

  /// Writes a note locally and queues it. [authorLabel]/[authorKind] are only for
  /// the optimistic row — the server stamps the authoritative values from the token.
  Future<Note> addNote(
    int animalLocalId,
    String body, {
    required String authorKind,
    required String authorLabel,
  }) async {
    return db.transaction(() async {
      final localId = await db.into(db.cachedNotes).insert(
            CachedNotesCompanion.insert(
              animalLocalId: animalLocalId,
              body: body,
              authorKind: Value(authorKind),
              authorLabel: Value(authorLabel),
              createdAt: DateTime.now(),
              pending: const Value(true),
            ),
          );
      await db.into(db.outboxEntries).insert(
            OutboxEntriesCompanion.insert(
              kind: OutboxKind.createNote.name,
              idempotencyKey: _uuid.v4(),
              targetLocalId: localId,
              animalLocalId: Value(animalLocalId),
              payload: jsonEncode({'body': body}),
              createdAt: DateTime.now(),
            ),
          );
      await _bumpNoteCount(animalLocalId, 1);
      final row = await (db.select(db.cachedNotes)
            ..where((n) => n.localId.equals(localId)))
          .getSingle();
      return _toNote(row);
    });
  }

  // --- refresh (server → cache) ---

  /// Pulls the herd into the cache. Rows created offline are matched by ear tag,
  /// so an animal the server already knows adopts its id instead of duplicating.
  Future<void> refreshHerd({int maxPages = 20}) async {
    final seen = <int>{};
    String? cursor;
    var pages = 0;

    do {
      final page = await api.animals(cursor: cursor);
      for (final animal in page.data) {
        seen.add(animal.serverId!);
        await _upsertAnimal(animal);
      }
      cursor = page.nextCursor;
      pages++;
    } while (cursor != null && pages < maxPages);

    // A full sweep saw the whole herd: drop synced rows the server no longer has.
    if (cursor == null) {
      await (db.delete(db.cachedAnimals)
            ..where((a) => a.pending.equals(false) & a.serverId.isNotIn(seen)))
          .go();
    }
  }

  /// Pulls one animal's notes into the cache, keeping any that are still queued.
  Future<void> refreshNotes(int animalLocalId, {int maxPages = 20}) async {
    final animal = await (db.select(db.cachedAnimals)
          ..where((a) => a.localId.equals(animalLocalId)))
        .getSingleOrNull();
    if (animal?.serverId == null) return; // never synced — nothing to pull yet

    final seen = <int>{};
    String? cursor;
    var pages = 0;
    do {
      final page = await api.notes(animal!.serverId!, cursor: cursor);
      for (final note in page.data) {
        seen.add(note.serverId!);
        await _upsertNote(animalLocalId, note);
      }
      cursor = page.nextCursor;
      pages++;
    } while (cursor != null && pages < maxPages);

    if (cursor == null) {
      await (db.delete(db.cachedNotes)
            ..where((n) =>
                n.animalLocalId.equals(animalLocalId) &
                n.pending.equals(false) &
                n.serverId.isNotIn(seen)))
          .go();
      await _recountNotes(animalLocalId);
    }
  }

  Future<void> _upsertAnimal(Animal animal) async {
    final existing = await (db.select(db.cachedAnimals)
          ..where((a) =>
              a.serverId.equals(animal.serverId!) | a.barcode.equals(animal.barcode))
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.cachedAnimals).insert(
            CachedAnimalsCompanion.insert(
              serverId: Value(animal.serverId),
              barcode: animal.barcode,
              noteCount: Value(animal.noteCount),
              createdAt: DateTime.now(),
            ),
          );
      return;
    }
    // Keep a locally-queued note count: it includes notes not yet on the server.
    final pendingNotes = await _pendingNoteCount(existing.localId);
    await (db.update(db.cachedAnimals)..where((a) => a.localId.equals(existing.localId)))
        .write(CachedAnimalsCompanion(
      serverId: Value(animal.serverId),
      barcode: Value(animal.barcode),
      noteCount: Value(animal.noteCount + pendingNotes),
      pending: const Value(false),
    ));
  }

  Future<void> _upsertNote(int animalLocalId, Note note) async {
    final existing = await (db.select(db.cachedNotes)
          ..where((n) => n.serverId.equals(note.serverId!))
          ..limit(1))
        .getSingleOrNull();

    if (existing == null) {
      await db.into(db.cachedNotes).insert(
            CachedNotesCompanion.insert(
              serverId: Value(note.serverId),
              animalLocalId: animalLocalId,
              body: note.body,
              authorKind: Value(note.authorKind),
              authorLabel: Value(note.authorLabel),
              createdAt: note.createdAt,
            ),
          );
      return;
    }
    await (db.update(db.cachedNotes)..where((n) => n.localId.equals(existing.localId)))
        .write(CachedNotesCompanion(
      body: Value(note.body),
      authorKind: Value(note.authorKind),
      authorLabel: Value(note.authorLabel),
      createdAt: Value(note.createdAt),
      pending: const Value(false),
    ));
  }

  Future<int> _pendingNoteCount(int animalLocalId) async {
    final count = countAll();
    final query = db.selectOnly(db.cachedNotes)
      ..addColumns([count])
      ..where(db.cachedNotes.animalLocalId.equals(animalLocalId) &
          db.cachedNotes.pending.equals(true));
    return await query.map((row) => row.read(count) ?? 0).getSingle();
  }

  Future<void> _bumpNoteCount(int animalLocalId, int delta) async {
    await db.customUpdate(
      'UPDATE cached_animals SET note_count = MAX(0, note_count + ?) WHERE local_id = ?',
      variables: [Variable.withInt(delta), Variable.withInt(animalLocalId)],
      updates: {db.cachedAnimals},
    );
  }

  Future<void> _recountNotes(int animalLocalId) async {
    await db.customUpdate(
      'UPDATE cached_animals SET note_count = '
      '(SELECT COUNT(*) FROM cached_notes WHERE animal_local_id = ?) WHERE local_id = ?',
      variables: [Variable.withInt(animalLocalId), Variable.withInt(animalLocalId)],
      updates: {db.cachedAnimals},
    );
  }

  Animal _toAnimal(CachedAnimal row) => Animal(
        localId: row.localId,
        serverId: row.serverId,
        barcode: row.barcode,
        noteCount: row.noteCount,
        pending: row.pending,
      );

  Note _toNote(CachedNote row) => Note(
        localId: row.localId,
        serverId: row.serverId,
        animalLocalId: row.animalLocalId,
        body: row.body,
        authorKind: row.authorKind,
        authorLabel: row.authorLabel,
        createdAt: row.createdAt,
        pending: row.pending,
      );
}
