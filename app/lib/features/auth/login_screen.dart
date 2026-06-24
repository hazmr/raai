import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _phone = TextEditingController();
  final _password = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _busy = false;

  @override
  void dispose() {
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(sessionControllerProvider.notifier).login(
            _phone.text.trim(),
            _password.text,
          );
      // Router redirect takes over once session becomes loggedIn.
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorText(t, e))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppTokens.s24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(t.appTitle, textAlign: TextAlign.center, style: Theme.of(context).textTheme.displaySmall),
                  const SizedBox(height: AppTokens.s24),
                  TextFormField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(labelText: t.phoneNumber),
                    validator: (v) => (v == null || v.trim().isEmpty) ? t.fieldRequired : null,
                  ),
                  const SizedBox(height: AppTokens.s12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: InputDecoration(labelText: t.password),
                    validator: (v) => (v == null || v.isEmpty) ? t.fieldRequired : null,
                  ),
                  const SizedBox(height: AppTokens.s24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox(height: 22, width: 22, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : Text(t.signIn),
                  ),
                  const SizedBox(height: AppTokens.s12),
                  TextButton(
                    onPressed: _busy ? null : () => context.go('/register'),
                    child: Text(t.needAccount),
                  ),
                  const Divider(height: AppTokens.s24),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : () => context.go('/doctor'),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: Text(t.enterAsDoctor),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
