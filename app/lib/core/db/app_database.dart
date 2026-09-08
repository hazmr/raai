import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

/// The herd, cached locally so it opens instantly and works with no signal (§7).
///
/// [serverId] is null for an animal registered offline: the row exists here and
/// on screen, and the outbox fills the id in once the POST lands.
class CachedAnimals extends Table {
  IntColumn get localId => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  TextColumn get barcode => text()();
  IntColumn get noteCount => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  /// True while this animal has not reached the server yet.
  BoolColumn get pending => boolean().withDefault(const Constant(false))();

  @override
  List<Set<Column>> get uniqueKeys => [
        {barcode},
      ];
}

/// Notes cached per animal. A note written offline is [pending] and shows in the
/// timeline immediately, marked as not-yet-synced.
class CachedNotes extends Table {
  IntColumn get localId => integer().autoIncrement()();
  IntColumn get serverId => integer().nullable()();
  IntColumn get animalLocalId =>
      integer().references(CachedAnimals, #localId, onDelete: KeyAction.cascade)();
  TextColumn get body => text()();
  TextColumn get authorKind => text().withDefault(const Constant('member'))();
  TextColumn get authorLabel => text().withDefault(const Constant(''))();
  DateTimeColumn get createdAt => dateTime()();
  BoolColumn get pending => boolean().withDefault(const Constant(false))();
}

/// The write queue. Every mutation made offline lands here first and is replayed
/// in order when the connection returns; [idempotencyKey] is minted once per
/// entry and reused on every retry, so a replay can never double-create (§6.1).
class OutboxEntries extends Table {
  IntColumn get id => integer().autoIncrement()();

  /// [OutboxKind] name: what to replay.
  TextColumn get kind => text()();

  /// Sent as the `Idempotency-Key` header; stable across retries.
  TextColumn get idempotencyKey => text()();

  /// The local row this entry creates (an animal or a note).
  IntColumn get targetLocalId => integer()();

  /// For a note: the animal it belongs to, so the sync can wait for that
  /// animal's server id before sending.
  IntColumn get animalLocalId => integer().nullable()();

  TextColumn get payload => text()();
  IntColumn get attempts => integer().withDefault(const Constant(0))();
  TextColumn get lastError => text().nullable()();

  /// Set when the server rejected the write for a reason a retry won't fix; the
  /// entry stops blocking the queue and is surfaced to the user instead.
  BoolColumn get failed => boolean().withDefault(const Constant(false))();

  DateTimeColumn get createdAt => dateTime()();
}

@DriftDatabase(tables: [CachedAnimals, CachedNotes, OutboxEntries])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  /// An isolated in-memory database, for tests.
  AppDatabase.memory() : super(NativeDatabase.memory());

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
        beforeOpen: (details) async {
          // Cascade deletes (animal → its notes) rely on this.
          await customStatement('PRAGMA foreign_keys = ON');
        },
      );

  /// Drops every cached row. Called on logout so the next person to sign in on a
  /// shared phone never sees the previous farm's herd.
  Future<void> clearAll() async {
    await transaction(() async {
      await delete(outboxEntries).go();
      await delete(cachedNotes).go();
      await delete(cachedAnimals).go();
    });
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    return NativeDatabase.createInBackground(File(p.join(dir.path, 'raai.sqlite')));
  });
}
