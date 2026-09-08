import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/sync/providers.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../core/widgets/sync_banner.dart';
import '../../l10n/app_localizations.dart';
import '../notes/add_note_sheet.dart';

final _animalProvider =
    StreamProvider.autoDispose.family<Animal?, int>((ref, localId) {
  return ref.watch(herdRepositoryProvider).watchAnimal(localId);
});

final _notesProvider =
    StreamProvider.autoDispose.family<List<Note>, int>((ref, localId) {
  return ref.watch(herdRepositoryProvider).watchNotes(localId);
});

/// Animal detail: ear-tag header + a newest-first notes timeline (§5.3), read
/// from the local cache so it opens instantly in the field. A doctor's note is
/// badged; a note still in the outbox is marked "not sent yet".
class AnimalDetailScreen extends ConsumerStatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId, this.initial});

  /// The animal's **local** id — an ear tag registered offline has no server id.
  final int animalId;
  final Animal? initial; // passed via go_router `extra` for an instant header

  @override
  ConsumerState<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends ConsumerState<AnimalDetailScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh(silent: true));
  }

  Future<void> _refresh({bool silent = false}) async {
    try {
      await ref.read(syncServiceProvider).drain();
      await ref.read(herdRepositoryProvider).refreshNotes(widget.animalId);
    } on ApiException catch (e) {
      if (!mounted || silent) return;
      final t = L10n.of(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(e.isOffline ? t.showingSavedData : errorText(t, e)),
      ));
    }
  }

  Future<void> _addNote() async {
    final saved = await showAddNoteSheet(context, animalLocalId: widget.animalId);
    if (saved == true && mounted) {
      final t = L10n.of(context);
      final queued = ref.read(pendingWritesProvider).value ?? 0;
      if (queued > 0) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(t.offlineSavedLocally)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final animal = ref.watch(_animalProvider(widget.animalId)).value ?? widget.initial;
    final notes = ref.watch(_notesProvider(widget.animalId));

    return Scaffold(
      appBar: AppBar(title: Text(animal?.barcode ?? t.tileHerd)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.add),
        label: Text(t.addNote),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SyncBanner(),
            Expanded(
              child: notes.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) =>
                    ErrorRetry(message: t.errGeneric, onRetry: _refresh),
                data: (rows) => RefreshIndicator(
                  onRefresh: _refresh,
                  child: rows.isEmpty
                      ? EmptyState(message: t.notesEmpty, icon: Icons.note_outlined)
                      : ListView.separated(
                          padding: const EdgeInsets.only(bottom: 96),
                          itemCount: rows.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, i) => _NoteTile(note: rows[i]),
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

class _NoteTile extends StatelessWidget {
  const _NoteTile({required this.note});
  final Note note;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .add_jm()
        .format(note.createdAt.toLocal());
    final author = note.authorLabel.isNotEmpty ? note.authorLabel : null;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s8),
      title: Row(
        children: [
          if (note.isDoctor) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTokens.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(AppTokens.rControl),
              ),
              child: Text(t.doctorBadge,
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: AppTokens.warning)),
            ),
            const SizedBox(width: AppTokens.s8),
          ],
          Expanded(
            child: Text(
              author != null ? '$author · $date' : date,
              style: const TextStyle(fontSize: 12, color: AppTokens.textSecondary),
            ),
          ),
          if (note.pending) ...[
            const SizedBox(width: AppTokens.s4),
            Icon(Icons.cloud_upload_outlined,
                size: 14, color: AppTokens.textSecondary,
                semanticLabel: t.notSentYet),
          ],
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppTokens.s4),
        child: Text(note.body, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}
