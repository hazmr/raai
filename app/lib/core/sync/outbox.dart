import 'dart:async';
import 'dart:convert';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:drift/drift.dart';

import '../api/api.dart';
import '../api/api_exception.dart';
import '../api/models.dart';
import '../db/app_database.dart';

/// What a queued write replays.
enum OutboxKind { createAnimal, createNote }

/// Why a drain stopped, so the UI can say something useful.
enum SyncStop {
  /// Queue emptied (or was already empty).
  done,

  /// No signal — the queue is intact and will be retried on reconnect.
  offline,

  /// The session ended or the farm's subscription lapsed; retrying now is futile.
  blocked,
}

/// The result of one drain pass.
class SyncOutcome {
  const SyncOutcome({required this.stop, this.sent = 0, this.failed = 0});

  final SyncStop stop;

  /// Writes accepted by the server on this pass.
  final int sent;

  /// Writes the server rejected for good; they stay queued but no longer block.
  final int failed;
}

/// Replays the outbox (§7).
///
/// Entries are sent oldest-first so a note can never arrive before the animal it
/// belongs to. Each carries the `Idempotency-Key` it was created with, so a
/// replay after a dropped response is answered with the original result instead
/// of creating a second row.
class SyncService {
  SyncService({required this.db, required this.api, Connectivity? connectivity})
      : _connectivity = connectivity ?? Connectivity();

  final AppDatabase db;
  final HerdApi api;
  final Connectivity _connectivity;

  StreamSubscription<List<ConnectivityResult>>? _connectionSub;
  Future<SyncOutcome>? _inFlight;

  /// Starts draining, and drains again whenever the connection comes back.
  Future<void> start() async {
    _connectionSub ??= _connectivity.onConnectivityChanged.listen((results) {
      final online = results.any((r) => r != ConnectivityResult.none);
      if (online) unawaited(drain());
    });
    await drain();
  }

  void dispose() {
    _connectionSub?.cancel();
    _connectionSub = null;
  }

  /// Number of writes still waiting to reach the server.
  Stream<int> watchPendingCount() {
    final count = countAll();
    final query = db.selectOnly(db.outboxEntries)
      ..addColumns([count])
      ..where(db.outboxEntries.failed.equals(false));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Writes the server refused; the app surfaces these so nothing is lost silently.
  Stream<int> watchFailedCount() {
    final count = countAll();
    final query = db.selectOnly(db.outboxEntries)
      ..addColumns([count])
      ..where(db.outboxEntries.failed.equals(true));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  /// Replays every queued write. Concurrent calls share one pass.
  Future<SyncOutcome> drain() {
    return _inFlight ??= _drain().whenComplete(() => _inFlight = null);
  }

  Future<SyncOutcome> _drain() async {
    var sent = 0;
    var failed = 0;

    final entries = await (db.select(db.outboxEntries)
          ..where((e) => e.failed.equals(false))
          ..orderBy([(e) => OrderingTerm(expression: e.id)]))
        .get();

    for (final entry in entries) {
      final outcome = await _send(entry);
      switch (outcome) {
        case _EntryResult.sent:
          sent++;
        case _EntryResult.rejected:
          failed++;
        case _EntryResult.waiting:
          continue; // its animal has not synced yet; a later pass picks it up
        case _EntryResult.offline:
          return SyncOutcome(stop: SyncStop.offline, sent: sent, failed: failed);
        case _EntryResult.blocked:
          return SyncOutcome(stop: SyncStop.blocked, sent: sent, failed: failed);
      }
    }
    return SyncOutcome(stop: SyncStop.done, sent: sent, failed: failed);
  }

  Future<_EntryResult> _send(OutboxEntry entry) async {
    try {
      switch (OutboxKind.values.byName(entry.kind)) {
        case OutboxKind.createAnimal:
          return await _sendAnimal(entry);
        case OutboxKind.createNote:
          return await _sendNote(entry);
      }
    } on ApiException catch (e) {
      return _classify(entry, e);
    }
  }

  Future<_EntryResult> _sendAnimal(OutboxEntry entry) async {
    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final barcode = payload['barcode'] as String;

    Animal? created;
    try {
      created = await api.createAnimal(barcode, idempotencyKey: entry.idempotencyKey);
    } on ApiException catch (e) {
      // A farm-mate registered the same ear tag first: adopt their row rather
      // than losing this one.
      if (e.status == 409) {
        final page = await api.animals(barcode: barcode);
        if (page.data.isEmpty) rethrow;
        created = page.data.first;
      } else {
        rethrow;
      }
    }

    await db.transaction(() async {
      await (db.update(db.cachedAnimals)
            ..where((a) => a.localId.equals(entry.targetLocalId)))
          .write(CachedAnimalsCompanion(
        serverId: Value(created!.serverId),
        pending: const Value(false),
      ));
      await (db.delete(db.outboxEntries)..where((e) => e.id.equals(entry.id))).go();
    });
    return _EntryResult.sent;
  }

  Future<_EntryResult> _sendNote(OutboxEntry entry) async {
    final animalLocalId = entry.animalLocalId;
    if (animalLocalId == null) return _EntryResult.rejected;

    final animal = await (db.select(db.cachedAnimals)
          ..where((a) => a.localId.equals(animalLocalId)))
        .getSingleOrNull();
    if (animal == null) {
      // The animal is gone; the note has nowhere to land.
      await _reject(entry, 'animal no longer exists');
      return _EntryResult.rejected;
    }
    if (animal.serverId == null) return _EntryResult.waiting;

    final payload = jsonDecode(entry.payload) as Map<String, dynamic>;
    final note = await api.createNote(
      animal.serverId!,
      payload['body'] as String,
      idempotencyKey: entry.idempotencyKey,
    );

    await db.transaction(() async {
      await (db.update(db.cachedNotes)
            ..where((n) => n.localId.equals(entry.targetLocalId)))
          .write(CachedNotesCompanion(
        serverId: Value(note.serverId),
        authorKind: Value(note.authorKind),
        authorLabel: Value(note.authorLabel),
        pending: const Value(false),
      ));
      await (db.delete(db.outboxEntries)..where((e) => e.id.equals(entry.id))).go();
    });
    return _EntryResult.sent;
  }

  /// Decides what a failure means for the queue: retry later, stop, or give up.
  Future<_EntryResult> _classify(OutboxEntry entry, ApiException e) async {
    if (e.isOffline) {
      await _touch(entry, 'offline');
      return _EntryResult.offline;
    }
    switch (e.status) {
      case 401: // session ended — the user has to sign in again
      case 402: // farm's subscription lapsed — pay first
        await _touch(entry, 'blocked (${e.status})');
        return _EntryResult.blocked;
      case 408:
      case 429:
      case 500:
      case 502:
      case 503:
      case 504:
        await _touch(entry, 'server unavailable (${e.status})');
        return _EntryResult.offline; // transient: keep the queue, try again later
      default:
        await _reject(entry, 'rejected (${e.status})');
        return _EntryResult.rejected;
    }
  }

  /// Records a retryable failure without consuming the entry.
  Future<void> _touch(OutboxEntry entry, String reason) async {
    await (db.update(db.outboxEntries)..where((e) => e.id.equals(entry.id)))
        .write(OutboxEntriesCompanion(
      attempts: Value(entry.attempts + 1),
      lastError: Value(reason),
    ));
  }

  /// Parks an entry a retry can't fix, so it stops blocking everything behind it.
  Future<void> _reject(OutboxEntry entry, String reason) async {
    await (db.update(db.outboxEntries)..where((e) => e.id.equals(entry.id)))
        .write(OutboxEntriesCompanion(
      attempts: Value(entry.attempts + 1),
      lastError: Value(reason),
      failed: const Value(true),
    ));
  }

  /// Puts parked entries back in the queue (the user asking "try again").
  Future<void> retryFailed() async {
    await db.update(db.outboxEntries).write(
          const OutboxEntriesCompanion(failed: Value(false), lastError: Value(null)),
        );
    await drain();
  }
}

enum _EntryResult { sent, rejected, waiting, offline, blocked }
