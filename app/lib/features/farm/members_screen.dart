import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../l10n/app_localizations.dart';

/// Farmers in the farm (admin only): list, add a login, remove. (farm refactor)
class MembersScreen extends ConsumerStatefulWidget {
  const MembersScreen({super.key});

  @override
  ConsumerState<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends ConsumerState<MembersScreen> {
  List<Member>? _items;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final m = await ref.read(apiProvider).members();
      if (mounted) setState(() => _items = m);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _add() async {
    final added = await showDialog<bool>(
      context: context,
      builder: (_) => const _AddFarmerDialog(),
    );
    if (added == true) _load();
  }

  Future<void> _remove(Member m) async {
    final t = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('${t.confirmRemove}\n${m.phoneNumber}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.remove)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).removeMember(m.userId);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tileFarmers)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.person_add),
        label: Text(t.addFarmer),
      ),
      body: SafeArea(child: _body(t)),
    );
  }

  Widget _body(L10n t) {
    if (_error != null && _items == null) {
      return ErrorRetry(message: errorText(t, _error!), onRetry: _load);
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) return EmptyState(message: t.membersEmpty, icon: Icons.group_outlined);
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final m = _items![i];
          final isAdmin = m.role == 'admin';
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s8),
            leading: Icon(isAdmin ? Icons.shield : Icons.person, color: AppTokens.primary),
            title: Text(m.phoneNumber, style: Theme.of(context).textTheme.bodyLarge),
            subtitle: Text(isAdmin ? t.roleAdmin : t.roleFarmer),
            trailing: isAdmin
                ? null
                : IconButton(
                    icon: const Icon(Icons.delete_outline, color: AppTokens.error),
                    onPressed: () => _remove(m),
                  ),
          );
        },
      ),
    );
  }
}

class _AddFarmerDialog extends ConsumerStatefulWidget {
  const _AddFarmerDialog();

  @override
  ConsumerState<_AddFarmerDialog> createState() => _AddFarmerDialogState();
}

class _AddFarmerDialogState extends ConsumerState<_AddFarmerDialog> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    if (_phone.text.trim().isEmpty || _password.text.length < 6) {
      setState(() => _error = t.passwordTooShort);
      return;
    }
    setState(() => _busy = true);
    try {
      await ref.read(apiProvider).addMember(_phone.text.trim(), _password.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = errorText(t, e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AlertDialog(
      title: Text(t.addFarmer),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(labelText: t.phoneNumber),
          ),
          const SizedBox(height: AppTokens.s12),
          TextField(
            controller: _password,
            decoration: InputDecoration(labelText: t.tempPassword, errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: _busy
              ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(t.save),
        ),
      ],
    );
  }
}
