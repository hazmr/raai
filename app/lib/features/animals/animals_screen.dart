import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/sync/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/sync_banner.dart';
import '../../l10n/app_localizations.dart';

/// What the search box currently holds; the herd stream re-runs as it changes.
final _queryProvider = StateProvider.autoDispose<String>((ref) => '');

/// The herd, straight from SQLite (§7) — it renders with no signal and updates
/// itself the moment a sync writes new rows.
final _herdProvider = StreamProvider.autoDispose<List<Animal>>((ref) {
  final query = ref.watch(_queryProvider);
  return ref.watch(herdRepositoryProvider).watchAnimals(query: query);
});

/// Herd list (§5.3): local-first, searchable by ear tag, pull-to-refresh pulls
/// from the server. Rows still waiting in the outbox are marked.
class AnimalsScreen extends ConsumerStatefulWidget {
  const AnimalsScreen({super.key});

  @override
  ConsumerState<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends ConsumerState<AnimalsScreen> {
  final _search = TextEditingController();
  bool _refreshing = false;

  @override
  void initState() {
    super.initState();
    // Fetch in the background; whatever is cached is already on screen.
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(silent: true));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _refresh({bool silent = false}) async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ref.read(syncServiceProvider).drain();
      await ref.read(herdRepositoryProvider).refreshHerd();
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      final t = L10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isOffline ? t.showingSavedData : errorText(t, e)),
      ));
    } finally {
      _refreshing = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final herd = ref.watch(_herdProvider);

    return Scaffold(
      appBar: AppBar(title: Text(t.tileHerd)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/animals/new'),
        icon: const Icon(Icons.add),
        label: Text(t.addAnimal),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SyncBanner(),
            Padding(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: TextField(
                controller: _search,
                onChanged: (v) =>
                    ref.read(_queryProvider.notifier).state = v.trim(),
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t.searchByTag,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: herd.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ErrorRetry(
                  message: t.errGeneric,
                  onRetry: () => ref.invalidate(_herdProvider),
                ),
                data: (animals) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: animals.isEmpty
                      ? EmptyState(message: t.herdEmpty, icon: Icons.pets_outlined)
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: animals.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) =>
                              _AnimalRow(animal: animals[i]),
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal});
  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s8),
      leading: const Icon(Icons.pets, color: AppTokens.primary),
      title: Text(animal.barcode, style: Theme.of(context).textTheme.bodyLarge),
      subtitle: Row(
        children: [
          Text(t.noteCountLabel(animal.noteCount)),
          if (animal.pending) ...[
            const SizedBox(width: AppTokens.s8),
            const Icon(Icons.cloud_upload_outlined,
                size: 14, color: AppTokens.textSecondary),
            const SizedBox(width: AppTokens.s4),
            Text(t.notSentYet,
                style: const TextStyle(
                    fontSize: 12, color: AppTokens.textSecondary)),
          ],
        ],
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.push('/animals/${animal.localId}', extra: animal),
    );
  }
}
