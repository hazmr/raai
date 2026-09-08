import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/sync/providers.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Add an animal (§5.3): one field (ear-tag barcode).
///
/// The tag is written to the local database and queued for delivery, so
/// registering an animal never depends on signal. A tag already in the herd is
/// reported inline instead of creating a duplicate. An [initialBarcode] (from
/// Scan) prefills the field.
class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key, this.initialBarcode});
  final String? initialBarcode;

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  late final _barcode = TextEditingController(text: widget.initialBarcode ?? '');
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _barcodeError;

  @override
  void dispose() {
    _barcode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    setState(() => _barcodeError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);

    final barcode = _barcode.text.trim();
    final repo = ref.read(herdRepositoryProvider);
    try {
      if (await repo.findByBarcode(barcode) != null) {
        if (mounted) setState(() => _barcodeError = t.errTagExists);
        return;
      }
      await repo.addAnimal(barcode);
      // Deliver now if we can; the outbox holds it if we can't.
      unawaited(ref.read(syncServiceProvider).drain());
      if (mounted) context.pop(true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.addAnimal)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _barcode,
                  autofocus: widget.initialBarcode == null,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _busy ? null : _submit(),
                  decoration:
                      InputDecoration(labelText: t.barcode, errorText: _barcodeError),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
                ),
                const SizedBox(height: AppTokens.s24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : Text(t.save),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
