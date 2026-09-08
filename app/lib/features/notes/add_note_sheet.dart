import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../core/auth/session.dart';
import '../../core/sync/providers.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// The field-friendly add-note sheet (§5.5): quick templates, dictation, and free
/// typing all fill a single `body`.
///
/// The note is written to the local database and queued, so it lands in the
/// timeline immediately whether or not there is signal. Authorship is set
/// server-side from the token; the local stamp is only for the optimistic row.
/// Returns true when a note was saved.
Future<bool?> showAddNoteSheet(
  BuildContext context, {
  required int animalLocalId,
}) {
  return showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: AppTokens.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppTokens.rTile)),
    ),
    builder: (_) => _AddNoteSheet(animalLocalId: animalLocalId),
  );
}

class _AddNoteSheet extends ConsumerStatefulWidget {
  const _AddNoteSheet({required this.animalLocalId});
  final int animalLocalId;

  @override
  ConsumerState<_AddNoteSheet> createState() => _AddNoteSheetState();
}

class _AddNoteSheetState extends ConsumerState<_AddNoteSheet> {
  final _body = TextEditingController();
  final _speech = SpeechToText();

  /// Text already in the field when dictation started, so speech appends to it
  /// instead of wiping what was typed.
  String _prefix = '';
  bool _listening = false;
  bool _busy = false;

  @override
  void dispose() {
    _body.dispose();
    if (_listening) _speech.cancel();
    super.dispose();
  }

  void _applyTemplate(String text) {
    _body.text = text;
    _body.selection = TextSelection.collapsed(offset: text.length);
    setState(() {});
  }

  // --- voice notes ---

  Future<void> _toggleDictation() async {
    final t = L10n.of(context);
    if (_listening) {
      await _speech.stop();
      if (mounted) setState(() => _listening = false);
      return;
    }

    final available = await _speech.initialize(
      onStatus: (status) {
        if (!mounted) return;
        if (status == 'done' || status == 'notListening') {
          setState(() => _listening = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _listening = false);
      },
    );
    if (!mounted) return;
    if (!available) {
      // Either the phone has no recognizer or the mic permission was refused.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(t.voiceUnavailable)),
      );
      return;
    }

    _prefix = _body.text.trimRight();
    setState(() => _listening = true);
    await _speech.listen(
      onResult: (result) {
        final spoken = result.recognizedWords;
        final combined = _prefix.isEmpty ? spoken : '$_prefix $spoken';
        _body.value = TextEditingValue(
          text: combined,
          selection: TextSelection.collapsed(offset: combined.length),
        );
        if (result.finalResult && mounted) setState(() => _listening = false);
      },
      listenOptions: SpeechListenOptions(
        partialResults: true,
        cancelOnError: true,
        // Arabic first — that is what the farmers and vets speak (§8).
        localeId: Localizations.localeOf(context).languageCode == 'ar' ? 'ar' : null,
      ),
    );
  }

  // --- saving ---

  Future<void> _submit() async {
    final body = _body.text.trim();
    if (body.isEmpty) return;
    if (_listening) await _speech.stop();

    setState(() => _busy = true);
    final session = ref.read(sessionControllerProvider);
    try {
      // Local write + outbox entry: this cannot fail for lack of signal.
      await ref.read(herdRepositoryProvider).addNote(
            widget.animalLocalId,
            body,
            authorKind: session.authorKind,
            authorLabel: session.label ?? '',
          );
      // Try to deliver right away; if it can't, the outbox keeps it.
      unawaited(ref.read(syncServiceProvider).drain());
      if (mounted) Navigator.of(context).pop(true);
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
          const SizedBox(height: AppTokens.s8),
          Row(
            children: [
              // Gloved hands in a barn: dictation is often easier than typing.
              OutlinedButton.icon(
                onPressed: _busy ? null : _toggleDictation,
                icon: Icon(_listening ? Icons.stop : Icons.mic),
                label: Text(_listening ? t.stop : t.voiceNote),
              ),
              if (_listening) ...[
                const SizedBox(width: AppTokens.s12),
                Text(t.voiceListening,
                    style: const TextStyle(color: AppTokens.textSecondary)),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.s16),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(t.send),
          ),
        ],
      ),
    );
  }
}
