import 'package:raai/core/api/api.dart';
import 'package:raai/core/api/api_exception.dart';
import 'package:raai/core/api/models.dart';

/// An in-memory stand-in for the server, so the outbox and repository can be
/// tested without a network: it records what was sent (including every
/// `Idempotency-Key`) and can be told to fail in specific, realistic ways.
class FakeHerdApi implements HerdApi {
  FakeHerdApi();

  /// Animals the "server" already knows, keyed by server id.
  final Map<int, Animal> serverAnimals = {};

  /// Notes per animal server id.
  final Map<int, List<Note>> serverNotes = {};

  /// Every idempotency key seen, in order — asserts that retries reuse one key.
  final List<String> keysSeen = [];

  /// Calls made, for asserting a queue drained in the right order.
  final List<String> calls = [];

  int _nextAnimalId = 1;
  int _nextNoteId = 1;

  /// When set, the next createAnimal/createNote throws this instead of succeeding.
  ApiException? failCreateWith;

  /// When true, every read/write behaves as if the phone has no signal.
  bool offline = false;

  Animal seedAnimal(String barcode, {int noteCount = 0}) {
    final animal = Animal(
      localId: 0,
      serverId: _nextAnimalId++,
      barcode: barcode,
      noteCount: noteCount,
    );
    serverAnimals[animal.serverId!] = animal;
    return animal;
  }

  Note seedNote(int animalServerId, String body, {String authorLabel = 'server'}) {
    final note = Note(
      localId: 0,
      animalLocalId: 0,
      serverId: _nextNoteId++,
      body: body,
      authorKind: 'member',
      authorLabel: authorLabel,
      createdAt: DateTime.now(),
    );
    serverNotes.putIfAbsent(animalServerId, () => []).add(note);
    return note;
  }

  void _guardOffline() {
    if (offline) throw ApiException(kind: ApiErrorKind.offline);
  }

  @override
  Future<Page<Animal>> animals({String? cursor, String? barcode, int limit = 50}) async {
    _guardOffline();
    calls.add('listAnimals(barcode: $barcode)');
    final all = serverAnimals.values.toList();
    if (barcode != null) {
      return Page(data: all.where((a) => a.barcode == barcode).toList());
    }
    return Page(data: all);
  }

  @override
  Future<Page<Note>> notes(int animalId, {String? cursor, int limit = 50}) async {
    _guardOffline();
    calls.add('listNotes($animalId)');
    return Page(data: List.of(serverNotes[animalId] ?? const []));
  }

  @override
  Future<Animal> createAnimal(String barcode, {String? idempotencyKey}) async {
    _guardOffline();
    calls.add('createAnimal($barcode)');
    if (idempotencyKey != null) keysSeen.add(idempotencyKey);
    final failure = failCreateWith;
    if (failure != null) {
      failCreateWith = null; // one-shot, so a retry can succeed
      throw failure;
    }
    final animal = Animal(
      localId: 0,
      serverId: _nextAnimalId++,
      barcode: barcode,
      noteCount: 0,
    );
    serverAnimals[animal.serverId!] = animal;
    return animal;
  }

  @override
  Future<Note> createNote(int animalId, String body, {String? idempotencyKey}) async {
    _guardOffline();
    calls.add('createNote($animalId)');
    if (idempotencyKey != null) keysSeen.add(idempotencyKey);
    final failure = failCreateWith;
    if (failure != null) {
      failCreateWith = null;
      throw failure;
    }
    final note = Note(
      localId: 0,
      animalLocalId: 0,
      serverId: _nextNoteId++,
      body: body,
      authorKind: 'member',
      authorLabel: 'server-stamped',
      createdAt: DateTime.now(),
    );
    serverNotes.putIfAbsent(animalId, () => []).add(note);
    return note;
  }
}
