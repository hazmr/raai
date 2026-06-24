import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Add an animal (§5.3): one field (ear-tag barcode) → `POST /animals`.
/// `409` ("tag already registered") shows inline on the field. Pops `true` on
/// success so the herd list refreshes. An [initialBarcode] (from Scan) prefills it.
class AddAnimalScreen extends ConsumerStatefulWidget {
  const AddAnimalScreen({super.key, this.initialBarcode});
  final String? initialBarcode;

  @override
  ConsumerState<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends ConsumerState<AddAnimalScreen> {
  late final _barcode = TextEditingController(text: widget.initialBarcode ?? '');
  final _formKey = GlobalKey<FormState>();
  final _idemKey = const Uuid().v4();
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
    try {
      await ref
          .read(apiProvider)
          .createAnimal(_barcode.text.trim(), idempotencyKey: _idemKey);
      if (mounted) context.pop(true);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        setState(() =>
            _barcodeError = errorText(t, e, ctx: ErrorContext.animalTag));
      } else {
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
