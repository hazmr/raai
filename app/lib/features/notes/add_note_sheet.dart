import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// The field-friendly add-note sheet (§5.5): quick templates + free typing fill a
/// single `body`. Authorship (member vs doctor) is set server-side from the token,
/// so the caller passes nothing extra. Returns the created [Note] or null.
Future<Note?> showAddNoteSheet(
  BuildContext context, {
  required int animalId,
}) {
  return showModalBottomSheet<Note>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rTile)),
    ),
    builder: (_) => _AddNoteSheet(animalId: animalId),
  );
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.animalId});
  final int animalId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _body = TextEditingController();
  // One idempotency key per sheet instance, reused across retries (§6.1).
  final _idemKey = const Uuid().v4();
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    super.dispose();
  }

  void _applyTemplate(String text) {
    _body.text = text;
    _body.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    final body = _body.text.trim();
    if (body.isEmpty) return;
    setState(() => _busy = true);
    try {
      final note = await ref.read(apiProvider).createNote(
            widget.animalId,
            body,
            idempotencyKey: _idemKey,
          );
      if (mounted) Navigator.of(context).pop(note);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    final templates = <String>[
      t.tplVaccination,
      t.tplCheckup,
      t.tplTreatment,
      t.tplBirth,
    ];
    // Lift the sheet above the keyboard.
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(
          AppTokens.s16, AppTokens.s16, AppTokens.s16, AppTokens.s16 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.addNote, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTokens.s12),
          Wrap(
            spacing: AppTokens.s8,
            runSpacing: AppTokens.s8,
            children: [
              for (final tpl in templates)
                ActionChip(label: Text(tpl), onPressed: () => _applyTemplate(tpl)),
            ],
          ),
          const SizedBox(height: AppTokens.s12),
          TextField(
            controller: _body,
            autofocus: true,
            minLines: 3,
            maxLines: 6,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(hintText: t.noteHint),
          ),
          const SizedBox(height: AppTokens.s16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : Text(t.send),
          ),
        ],
      ),
    );
  }
}
