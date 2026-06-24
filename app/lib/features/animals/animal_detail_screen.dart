import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../l10n/app_localizations.dart';
import '../notes/add_note_sheet.dart';

/// Animal detail: header (ear tag) + a newest-first notes timeline (§5.3).
/// A vet's note is badged. The FAB opens the add-note sheet (§5.5).
class AnimalDetailScreen extends ConsumerStatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId, this.initial});
  final int animalId;
  final Animal? initial; // passed via go_router `extra` for an instant header

  @override
  ConsumerState<AnimalDetailScreen> createState() => _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends ConsumerState<AnimalDetailScreen> {
  final _scroll = ScrollController();
  final List<Note> _notes = [];
  Animal? _animal;
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _firstLoad = true;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _animal = widget.initial;
    _scroll.addListener(_onScroll);
    _loadAnimalIfNeeded();
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadAnimalIfNeeded() async {
    if (_animal != null) return;
    try {
      final a = await ref.read(apiProvider).animal(widget.animalId);
      if (mounted) setState(() => _animal = a);
    } on ApiException {
      // Header just stays minimal; the notes list surfaces any real error.
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await ref
          .read(apiProvider)
          .notes(widget.animalId, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _notes.addAll(page.data);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _firstLoad = false;
        });
      }
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _notes.clear();
      _cursor = null;
      _hasMore = true;
      _firstLoad = true;
    });
    await _loadMore();
  }

  Future<void> _addNote() async {
    final note = await showAddNoteSheet(context, animalId: widget.animalId);
    if (note != null && mounted) setState(() => _notes.insert(0, note));
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(_animal?.barcode ?? t.tileHerd)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addNote,
        icon: const Icon(Icons.add),
        label: Text(t.addNote),
      ),
      body: SafeArea(child: _body(t)),
    );
  }

  Widget _body(L10n t) {
    if (_firstLoad && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_firstLoad && _error != null) {
      return ErrorRetry(message: errorText(t, _error!), onRetry: _refresh);
    }
    return RefreshIndicator(
      onRefresh: _refresh,
      child: _notes.isEmpty
          ? EmptyState(message: t.notesEmpty, icon: Icons.note_outlined)
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _notes.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= _notes.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppTokens.s16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                return _NoteTile(note: _notes[i]);
              },
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
    final isDoctor = note.isDoctor;
    final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
        .add_jm()
        .format(note.createdAt.toLocal());
    // Whoever wrote it: a doctor's note is badged; the stamped author label shows.
    final author = note.authorLabel.isNotEmpty ? note.authorLabel : null;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s8),
      title: Row(
        children: [
          if (isDoctor) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppTokens.warning.withOpacity(0.12),
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
        ],
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppTokens.s4),
        child: Text(note.body, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

