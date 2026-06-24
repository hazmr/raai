import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../l10n/app_localizations.dart';

/// Herd list (§5.3): cursor-paginated, infinite scroll, search by ear tag
/// (`?barcode=`). Plain rows — tag + note count. FAB adds an animal.
class AnimalsScreen extends ConsumerStatefulWidget {
  const AnimalsScreen({super.key});

  @override
  ConsumerState<AnimalsScreen> createState() => _AnimalsScreenState();
}

class _AnimalsScreenState extends ConsumerState<AnimalsScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final List<Animal> _items = [];
  String _query = '';
  String? _cursor;
  bool _hasMore = true;
  bool _loading = false;
  bool _firstLoad = true;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 300) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    final q = _query;
    try {
      final page = await ref.read(apiProvider).animals(
            cursor: _cursor,
            barcode: q.isEmpty ? null : q,
          );
      if (!mounted || q != _query) return; // search moved on — drop stale page
      setState(() {
        _items.addAll(page.data);
        _cursor = page.nextCursor;
        _hasMore = page.nextCursor != null;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted && q == _query) setState(() => _error = e);
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
          _firstLoad = false;
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _items.clear();
      _cursor = null;
      _hasMore = true;
      _firstLoad = true;
      _error = null;
    });
    await _loadMore();
  }

  void _onSearchChanged(String value) {
    _query = value.trim();
    _reload();
  }

  Future<void> _addAnimal() async {
    final created = await context.push<bool>('/animals/new');
    if (created == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tileHerd)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addAnimal,
        icon: const Icon(Icons.add),
        label: Text(t.addAnimal),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(AppTokens.s16),
              child: TextField(
                controller: _search,
                onChanged: _onSearchChanged,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: t.searchByTag,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(child: _list(t)),
          ],
        ),
      ),
    );
  }

  Widget _list(L10n t) {
    if (_firstLoad && _loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_firstLoad && _error != null) {
      return ErrorRetry(message: errorText(t, _error!), onRetry: _reload);
    }
    return RefreshIndicator(
      onRefresh: _reload,
      child: _items.isEmpty
          ? EmptyState(message: t.herdEmpty, icon: Icons.pets_outlined)
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: _items.length + (_hasMore ? 1 : 0),
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                if (i >= _items.length) {
                  return const Padding(
                    padding: EdgeInsets.all(AppTokens.s16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final a = _items[i];
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppTokens.s16, vertical: AppTokens.s8),
                  leading: const Icon(Icons.pets, color: AppTokens.primary),
                  title: Text(a.barcode,
                      style: Theme.of(context).textTheme.bodyLarge),
                  subtitle: Text(t.noteCountLabel(a.noteCount)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/animals/${a.id}', extra: a),
                );
              },
            ),
    );
  }
}
