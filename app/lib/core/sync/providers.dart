import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/session.dart';
import '../db/app_database.dart';
import '../repo/herd_repository.dart';
import 'outbox.dart';

/// The on-device SQLite database. One instance for the app's lifetime.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

/// Local-first herd access — every screen reads through this, never the API.
final herdRepositoryProvider = Provider<HerdRepository>((ref) {
  return HerdRepository(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(apiProvider),
  );
});

/// Replays queued writes whenever the phone has a connection.
final syncServiceProvider = Provider<SyncService>((ref) {
  final sync = SyncService(
    db: ref.watch(appDatabaseProvider),
    api: ref.watch(apiProvider),
  );
  ref.onDispose(sync.dispose);
  return sync;
});

/// How many writes are still waiting to reach the server (drives the "N not sent
/// yet" chip).
final pendingWritesProvider = StreamProvider<int>((ref) {
  return ref.watch(syncServiceProvider).watchPendingCount();
});

/// Writes the server refused; the user is offered a retry.
final failedWritesProvider = StreamProvider<int>((ref) {
  return ref.watch(syncServiceProvider).watchFailedCount();
});
