import 'package:drift/drift.dart' show OrderingTerm;
import 'package:flutter_test/flutter_test.dart';
import 'package:raai/core/db/app_database.dart';
import 'package:raai/core/repo/herd_repository.dart';

import '../support/fake_herd_api.dart';

void main() {
  late AppDatabase db;
  late FakeHerdApi api;
  late HerdRepository repo;

  setUp(() {
    db = AppDatabase.memory();
    api = FakeHerdApi();
    repo = HerdRepository(db: db, api: api);
  });

  tearDown(() => db.close());

  Future<List<OutboxEntry>> outbox() =>
      (db.select(db.outboxEntries)..orderBy([(e) => OrderingTerm(expression: e.id)])).get();

  group('writing offline', () {
    test('an ear tag is stored locally and queued', () async {
      final animal = await repo.addAnimal('12345');

      expect(animal.barcode, '12345');
      expect(animal.pending, isTrue, reason: 'not yet delivered to the server');
      expect(animal.serverId, isNull);
      expect(animal.localId, greaterThan(0), reason: 'addressable straight away');

      final queued = await outbox();
      expect(queued, hasLength(1));
      expect(queued.single.kind, 'createAnimal');
      expect(queued.single.targetLocalId, animal.localId);
      expect(queued.single.idempotencyKey, isNotEmpty);
      expect(queued.single.failed, isFalse);
    });

    test('a note is stored locally, queued, and counted', () async {
      final animal = await repo.addAnimal('12345');
      final note = await repo.addNote(animal.localId, 'حرارة مرتفعة',
          authorKind: 'member', authorLabel: '01000000000');

      expect(note.body, 'حرارة مرتفعة');
      expect(note.pending, isTrue);
      expect(note.authorLabel, '01000000000');

      final queued = await outbox();
      expect(queued.map((e) => e.kind), ['createAnimal', 'createNote'],
          reason: 'the animal must be sent before its note');
      expect(queued.last.animalLocalId, animal.localId);

      final stored = await repo.watchAnimal(animal.localId).first;
      expect(stored!.noteCount, 1, reason: 'the list shows the note immediately');
    });

    test('every queued write gets its own idempotency key', () async {
      final animal = await repo.addAnimal('12345');
      await repo.addNote(animal.localId, 'one', authorKind: 'member', authorLabel: 'a');
      await repo.addNote(animal.localId, 'two', authorKind: 'member', authorLabel: 'a');

      final keys = (await outbox()).map((e) => e.idempotencyKey).toSet();
      expect(keys, hasLength(3));
    });

    test('re-adding a tag already in the herd returns the existing animal', () async {
      final first = await repo.addAnimal('12345');
      final second = await repo.addAnimal('12345');

      expect(second.localId, first.localId);
      expect(await outbox(), hasLength(1), reason: 'no duplicate write queued');
    });
  });

  group('reading', () {
    test('the herd is newest first and filtered by ear tag', () async {
      await repo.addAnimal('11111');
      await repo.addAnimal('22222');
      await repo.addAnimal('22233');

      final all = await repo.watchAnimals().first;
      expect(all.map((a) => a.barcode), ['22233', '22222', '11111']);

      final filtered = await repo.watchAnimals(query: '222').first;
      expect(filtered.map((a) => a.barcode), ['22233', '22222']);
    });

    test('notes come back newest first', () async {
      final animal = await repo.addAnimal('12345');
      await repo.addNote(animal.localId, 'first', authorKind: 'member', authorLabel: 'a');
      await repo.addNote(animal.localId, 'second', authorKind: 'member', authorLabel: 'a');

      final notes = await repo.watchNotes(animal.localId).first;
      expect(notes.map((n) => n.body), ['second', 'first']);
    });

    test('a scan finds a tag without touching the network', () async {
      await repo.addAnimal('12345');
      api.offline = true;

      expect((await repo.findByBarcode('12345'))!.barcode, '12345');
      expect(await repo.findByBarcode('99999'), isNull);
      expect(api.calls, isEmpty, reason: 'the scanner must not need signal');
    });
  });

  group('refreshing from the server', () {
    test('server animals land in the cache', () async {
      api.seedAnimal('11111', noteCount: 2);
      api.seedAnimal('22222');

      await repo.refreshHerd();

      final herd = await repo.watchAnimals().first;
      expect(herd, hasLength(2));
      expect(herd.every((a) => a.serverId != null), isTrue);
      expect(herd.every((a) => a.pending), isFalse);
      expect(herd.firstWhere((a) => a.barcode == '11111').noteCount, 2);
    });

    test('an offline row adopts the server id of the same ear tag', () async {
      final local = await repo.addAnimal('12345');
      api.seedAnimal('12345');

      await repo.refreshHerd();

      final herd = await repo.watchAnimals().first;
      expect(herd, hasLength(1), reason: 'the same animal, not a duplicate');
      expect(herd.single.localId, local.localId, reason: 'the local row survives');
      expect(herd.single.serverId, isNotNull);
      expect(herd.single.pending, isFalse);
    });

    test('animals deleted on the server drop out of the cache', () async {
      api.seedAnimal('11111');
      await repo.refreshHerd();
      expect(await repo.watchAnimals().first, hasLength(1));

      api.serverAnimals.clear();
      await repo.refreshHerd();
      expect(await repo.watchAnimals().first, isEmpty);
    });

    test('a refresh never discards a write still waiting to be sent', () async {
      await repo.addAnimal('12345'); // queued, unknown to the server
      api.seedAnimal('99999');

      await repo.refreshHerd();

      final herd = await repo.watchAnimals().first;
      expect(herd.map((a) => a.barcode).toSet(), {'12345', '99999'});
      expect(herd.firstWhere((a) => a.barcode == '12345').pending, isTrue);
    });

    test('refreshing notes keeps queued ones and adopts server ones', () async {
      final serverAnimal = api.seedAnimal('12345');
      await repo.refreshHerd();
      final local = (await repo.watchAnimals().first).single;

      api.seedNote(serverAnimal.serverId!, 'from the vet');
      await repo.addNote(local.localId, 'mine, not sent yet',
          authorKind: 'member', authorLabel: 'me');

      await repo.refreshNotes(local.localId);

      final notes = await repo.watchNotes(local.localId).first;
      expect(notes.map((n) => n.body).toSet(), {'from the vet', 'mine, not sent yet'});
      expect(notes.where((n) => n.pending).map((n) => n.body), ['mine, not sent yet']);
    });

    test('notes are not fetched for an animal that has never synced', () async {
      final local = await repo.addAnimal('12345');

      await repo.refreshNotes(local.localId);

      expect(api.calls, isEmpty, reason: 'there is no server id to ask about yet');
    });
  });

  test('clearAll wipes the cache when a session ends', () async {
    final animal = await repo.addAnimal('12345');
    await repo.addNote(animal.localId, 'note', authorKind: 'member', authorLabel: 'a');

    await db.clearAll();

    expect(await repo.watchAnimals().first, isEmpty);
    expect(await repo.watchNotes(animal.localId).first, isEmpty);
    expect(await outbox(), isEmpty);
  });
}
