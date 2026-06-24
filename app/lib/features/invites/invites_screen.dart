import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../l10n/app_localizations.dart';

/// Doctor visits (admin only): create a temporary QR invite (shown for the doctor
/// to scan), review the full history of who did what, and end access. (farm refactor)
class InvitesScreen extends ConsumerStatefulWidget {
  const InvitesScreen({super.key});

  @override
  ConsumerState<InvitesScreen> createState() => _InvitesScreenState();
}

class _InvitesScreenState extends ConsumerState<InvitesScreen> {
  List<Invite>? _items;
  ApiException? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final v = await ref.read(apiProvider).invites();
      if (mounted) setState(() => _items = v);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _create() async {
    final t = L10n.of(context);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _NewInviteDialog(),
    );
    if (name == null || name.isEmpty) return;
    try {
      final inv = await ref.read(apiProvider).createInvite(name);
      if (!mounted) return;
      await _showQr(inv); // present the QR right away
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    }
  }

  Future<void> _showQr(Invite inv) {
    final t = L10n.of(context);
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(inv.doctorLabel),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(t.inviteShowQr, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.s16),
            if (inv.token != null)
              Container(
                padding: const EdgeInsets.all(AppTokens.s12),
                color: Colors.white,
                child: QrImageView(data: inv.token!, size: 220),
              ),
            const SizedBox(height: AppTokens.s12),
            Text(t.inviteScanHint,
                textAlign: TextAlign.center,
                style: Theme.of(ctx).textTheme.labelSmall),
          ],
        ),
        actions: [
          FilledButton(onPressed: () => Navigator.pop(ctx), child: Text(t.close)),
        ],
      ),
    );
  }

  Future<void> _end(Invite inv) async {
    final t = L10n.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text('${t.confirmEnd}\n${inv.doctorLabel}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: Text(t.endAccess)),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(apiProvider).endInvite(inv.id);
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
      appBar: AppBar(title: Text(t.tileDoctors)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.qr_code_2),
        label: Text(t.newDoctorVisit),
      ),
      body: SafeArea(child: _body(t)),
    );
  }

  Widget _body(L10n t) {
    if (_error != null && _items == null) {
      return ErrorRetry(message: errorText(t, _error!), onRetry: _load);
    }
    if (_items == null) return const Center(child: CircularProgressIndicator());
    if (_items!.isEmpty) {
      return EmptyState(message: t.invitesEmpty, icon: Icons.medical_services_outlined);
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: _items!.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) {
          final inv = _items![i];
          final date = DateFormat.yMMMd(Localizations.localeOf(context).languageCode)
              .format(inv.createdAt.toLocal());
          return ListTile(
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s8),
            leading: Icon(
              inv.isActive ? Icons.medical_services : Icons.history,
              color: inv.isActive ? AppTokens.success : AppTokens.textSecondary,
            ),
            title: Text(inv.doctorLabel, style: Theme.of(context).textTheme.bodyLarge),
            subtitle: Text(
                '$date · ${inv.isActive ? t.inviteActive : t.inviteEnded} · ${t.notesWritten(inv.noteCount)}'),
            trailing: inv.isActive
                ? TextButton(onPressed: () => _end(inv), child: Text(t.endAccess))
                : null,
          );
        },
      ),
    );
  }
}

class _NewInviteDialog extends StatefulWidget {
  const _NewInviteDialog();

  @override
  State<_NewInviteDialog> createState() => _NewInviteDialogState();
}

class _NewInviteDialogState extends State<_NewInviteDialog> {
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return AlertDialog(
      title: Text(t.newDoctorVisit),
      content: TextField(
        controller: _name,
        autofocus: true,
        decoration: InputDecoration(labelText: t.doctorName),
        onSubmitted: (v) => Navigator.pop(context, v.trim()),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(t.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, _name.text.trim()),
          child: Text(t.createInvite),
        ),
      ],
    );
  }
}
