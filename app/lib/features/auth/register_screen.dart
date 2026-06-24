import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

/// Sign-up is **farmer-only**: only a herder (راعي) — the herd owner who pays —
/// can self-register. Vet accounts are provisioned out-of-band (admin), never
/// through the app, so there is no role toggle here.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _farmName = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;
  String? _phoneError; // inline 409 (phone already registered)

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    _farmName.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    setState(() => _phoneError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).register(
            _phone.text.trim(),
            _password.text,
            _farmName.text.trim(),
          );
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        setState(() => _phoneError = errorText(t, e)); // "phone already registered"-ish
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.createAccount)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppTokens.s24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(labelText: t.phoneNumber, errorText: _phoneError),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
                ),
                const SizedBox(height: AppTokens.s12),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  decoration: InputDecoration(labelText: t.password),
                  validator: (v) => (v == null || v.length < 6) ? t.passwordTooShort : null,
                ),
                const SizedBox(height: AppTokens.s12),
                TextFormField(
                  controller: _farmName,
                  decoration: InputDecoration(labelText: t.farmName),
                  validator: (v) => (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
                ),
                const SizedBox(height: AppTokens.s24),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(t.createAccount),
                ),
                const SizedBox(height: AppTokens.s12),
                TextButton(
                  onPressed: _busy ? null : () => context.go('/login'),
                  child: Text(t.haveAccount),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
