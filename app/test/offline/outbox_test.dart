import 'package:drift/drift.dart' show OrderingTerm, Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:raai/core/api/api_exception.dart';
import 'package:raai/core/db/app_database.dart';
import 'package:raai/core/repo/herd_repository.dart';
import 'package:raai/core/sync/outbox.dart';

import '../support/fake_herd_api.dart';

void main() {
  late AppDatabase db;
  late FakeHerdApi api;
  late HerdRepository repo;
  late SyncService sync;

  setUp(() {
    db = AppDatabase.memory();
    api = FakeHerdApi();
    repo = HerdRepository(db: db, api: api);
    sync = SyncService(db: db, api: api);
  });

  tearDown(() => db.close());

  Future<List<OutboxEntry>> outbox() =>
      (db.select(db.outboxEntries)..orderBy([(e) => OrderingTerm(expression: e.id)])).get();

  ApiException serverError(int status) =>
      ApiException(kind: ApiErrorKind.server, status: status);

  test('a queued animal and its note are delivered in order', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'أعطيت المضاد الحيوي',
        authorKind: 'member', authorLabel: '01000000000');

    final outcome = await sync.drain();

    expect(outcome.stop, SyncStop.done);
    expect(outcome.sent, 2);
    expect(api.calls, ['createAnimal(12345)', 'createNote(1)'],
        reason: 'a note can never reach the server before its animal');
    expect(await outbox(), isEmpty);

    final stored = await repo.watchAnimal(animal.localId).first;
    expect(stored!.serverId, isNotNull);
    expect(stored.pending, isFalse);

    final notes = await repo.watchNotes(animal.localId).first;
    expect(notes.single.serverId, isNotNull);
    expect(notes.single.pending, isFalse);
    expect(notes.single.authorLabel, 'server-stamped',
        reason: "the server's authorship wins over the optimistic stamp");
  });

  test('with no signal the queue is kept intact', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');
    api.offline = true;

    final outcome = await sync.drain();

    expect(outcome.stop, SyncStop.offline);
    expect(outcome.sent, 0);
    expect(await outbox(), hasLength(2), reason: 'nothing may be lost');
    expect((await outbox()).first.attempts, 1);
    expect((await outbox()).first.failed, isFalse);
  });

  test('the queue drains once the signal comes back', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');
    api.offline = true;
    await sync.drain();

    api.offline = false;
    final outcome = await sync.drain();

    expect(outcome.stop, SyncStop.done);
    expect(outcome.sent, 2);
    expect(await outbox(), isEmpty);
  });

  test('a retry re-sends the original idempotency key', () async {
    await repo.addAnimal('12345');
    final key = (await outbox()).single.idempotencyKey;

    api.failCreateWith = serverError(503); // transient
    await sync.drain();
    expect(await outbox(), hasLength(1), reason: 'still queued after a 503');

    await sync.drain();

    expect(api.keysSeen, [key, key],
        reason: 'the replay must carry the same key so the server can dedupe');
    expect(await outbox(), isEmpty);
  });

  test('an ear tag a farm-mate registered first is adopted, not lost', () async {
    final animal = await repo.addAnimal('12345');
    api.seedAnimal('12345'); // someone else got there first
    api.failCreateWith = serverError(409);

    final outcome = await sync.drain();

    expect(outcome.stop, SyncStop.done);
    expect(await outbox(), isEmpty);

    final stored = await repo.watchAnimal(animal.localId).first;
    expect(stored!.serverId, isNotNull, reason: 'adopted the existing animal');
    expect(stored.pending, isFalse);
    expect(await repo.watchAnimals().first, hasLength(1), reason: 'no duplicate row');
  });

  test('a lapsed subscription stops the queue without discarding it', () async {
    await repo.addAnimal('12345');
    api.failCreateWith = serverError(402);

    final outcome = await sync.drain();

    expect(outcome.stop, SyncStop.blocked);
    expect(outcome.failed, 0);
    expect(await outbox(), hasLength(1));
    expect((await outbox()).single.failed, isFalse,
        reason: 'it will go through once the farm pays');
  });

  test('an expired session stops the queue', () async {
    await repo.addAnimal('12345');
    api.failCreateWith = serverError(401);

    expect((await sync.drain()).stop, SyncStop.blocked);
    expect(await outbox(), hasLength(1));
  });

  test('a write the server refuses is parked and stops blocking the rest', () async {
    await repo.addAnimal('11111');
    await repo.addAnimal('22222');
    api.failCreateWith = serverError(422); // e.g. a tag the server rejects

    final outcome = await sync.drain();

    expect(outcome.failed, 1);
    expect(outcome.sent, 1, reason: 'the second animal still went through');

    final remaining = await outbox();
    expect(remaining, hasLength(1));
    expect(remaining.single.failed, isTrue);
    expect(remaining.single.lastError, contains('422'));
  });

  test('a note waits while its animal is still unsent', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');

    // Park the animal's write, as a permanent rejection would.
    await (db.update(db.outboxEntries)..where((e) => e.kind.equals('createAnimal')))
        .write(const OutboxEntriesCompanion(failed: Value(true)));

    final outcome = await sync.drain();

    expect(outcome.sent, 0);
    expect(api.calls, isEmpty, reason: 'the note has no animal id to attach to');
    final noteEntry = (await outbox()).where((e) => e.kind == 'createNote');
    expect(noteEntry, hasLength(1), reason: 'it waits rather than failing');
    expect(noteEntry.single.failed, isFalse);
  });

  test('a note whose animal was deleted is parked rather than retried forever', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');
    await sync.drain(); // animal and note both delivered

    // Queue a second note, then delete the animal underneath it.
    await repo.addNote(animal.localId, 'orphan', authorKind: 'member', authorLabel: 'a');
    await (db.delete(db.cachedAnimals)..where((a) => a.localId.equals(animal.localId))).go();

    final outcome = await sync.drain();

    expect(outcome.failed, 1);
    expect((await outbox()).single.failed, isTrue);
  });

  test('retryFailed puts parked writes back in the queue', () async {
    await repo.addAnimal('11111');
    api.failCreateWith = serverError(422);
    await sync.drain();
    expect((await outbox()).single.failed, isTrue);

    await sync.retryFailed();

    expect(await outbox(), isEmpty, reason: 'the retry succeeded');
    expect(api.serverAnimals.values.map((a) => a.barcode), contains('11111'));
  });

  test('the pending count tracks the queue', () async {
    expect(await sync.watchPendingCount().first, 0);

    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');
    expect(await sync.watchPendingCount().first, 2);

    await sync.drain();
    expect(await sync.watchPendingCount().first, 0);
  });

  test('the failed count tracks parked writes', () async {
    await repo.addAnimal('11111');
    api.failCreateWith = serverError(422);
    await sync.drain();

    expect(await sync.watchFailedCount().first, 1);
    expect(await sync.watchPendingCount().first, 0,
        reason: 'parked writes are reported separately, not as pending');
  });

  test('concurrent drains share a single pass', () async {
    await repo.addAnimal('12345');

    await Future.wait([sync.drain(), sync.drain(), sync.drain()]);

    expect(api.calls.where((c) => c.startsWith('createAnimal')), hasLength(1),
        reason: 'overlapping triggers must not double-send');
  });

  test('an empty queue is a no-op', () async {
    final outcome = await sync.drain();
    expect(outcome.stop, SyncStop.done);
    expect(outcome.sent, 0);
    expect(api.calls, isEmpty);
  });
}
