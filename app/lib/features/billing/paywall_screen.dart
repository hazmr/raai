import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/api/api_exception.dart';
import '../../core/api/error_text.dart';
import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../core/widgets/states.dart';
import '../../l10n/app_localizations.dart';

/// Paywall (§5.7, farmer only): show plans + the pay-to IPA with a Copy button,
/// take a transferred reference, submit it as a pending payment, then poll
/// `GET /billing/status` until an admin confirms it (status → active).
class PaywallScreen extends ConsumerStatefulWidget {
  const PaywallScreen({super.key});

  @override
  ConsumerState<PaywallScreen> createState() => _PaywallScreenState();
}

class _PaywallScreenState extends ConsumerState<PaywallScreen> {
  final _reference = TextEditingController();
  final _screenshot = TextEditingController();
  final _idemKey = const Uuid().v4();

  PlansResponse? _plans;
  String _selectedPlan = 'monthly';
  bool _loadingPlans = true;
  ApiException? _loadError;

  bool _submitting = false;
  String? _referenceError;
  bool _underReview = false;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadPlans();
  }

  @override
  void dispose() {
    _poll?.cancel();
    _reference.dispose();
    _screenshot.dispose();
    super.dispose();
  }

  Future<void> _loadPlans() async {
    setState(() {
      _loadingPlans = true;
      _loadError = null;
    });
    try {
      final plans = await ref.read(apiProvider).billingPlans();
      if (!mounted) return;
      setState(() {
        _plans = plans;
        if (plans.plans.isNotEmpty) _selectedPlan = plans.plans.first.id;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e);
    } finally {
      if (mounted) setState(() => _loadingPlans = false);
    }
  }

  Future<void> _copyIpa() async {
    final t = L10n.of(context);
    await Clipboard.setData(ClipboardData(text: _plans?.instapayIpa ?? ''));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.copied)));
    }
  }

  Future<void> _submit() async {
    final t = L10n.of(context);
    final ref0 = _reference.text.trim();
    setState(() => _referenceError = null);
    if (ref0.isEmpty) {
      setState(() => _referenceError = t.fieldRequired);
      return;
    }
    final plan = _plans!.plans.firstWhere((p) => p.id == _selectedPlan);
    setState(() => _submitting = true);
    try {
      await ref.read(apiProvider).submitPayment(
            plan: plan.id,
            instapayRef: ref0,
            amountEgp: plan.amountEgp.toDouble(),
            screenshotUrl:
                _screenshot.text.trim().isEmpty ? null : _screenshot.text.trim(),
            idempotencyKey: _idemKey,
          );
      if (mounted) {
        setState(() => _underReview = true);
        _startPolling();
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409) {
        setState(() =>
            _referenceError = errorText(t, e, ctx: ErrorContext.receipt));
      } else {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(errorText(t, e))));
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _startPolling() {
    _poll?.cancel();
    _poll = Timer.periodic(const Duration(seconds: 5), (_) async {
      try {
        final status = await ref.read(apiProvider).billingStatus();
        if (status.isActive && mounted) {
          _poll?.cancel();
          ref.read(paywallProvider.notifier).state = false;
          ref.invalidate(apiProvider); // refresh home tiles next read
          context.go('/home');
        }
      } on ApiException {
        // transient — keep polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(t.tileSubscription)),
      body: SafeArea(child: _body(t)),
    );
  }

  Widget _body(L10n t) {
    if (_loadingPlans) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ErrorRetry(message: errorText(t, _loadError!), onRetry: _loadPlans);
    }
    if (_underReview) return _UnderReview(onClose: () => context.go('/home'));

    final plans = _plans!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTokens.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(t.choosePlan, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppTokens.s12),
          for (final p in plans.plans) _planTile(t, p),
          const SizedBox(height: AppTokens.s24),
          _PayToCard(
            displayName: plans.displayName,
            ipa: plans.instapayIpa,
            onCopy: _copyIpa,
          ),
          const SizedBox(height: AppTokens.s16),
          Text(t.paywallStep, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppTokens.s8),
          TextField(
            controller: _reference,
            decoration: InputDecoration(
                labelText: t.referenceLabel, errorText: _referenceError),
          ),
          const SizedBox(height: AppTokens.s12),
          TextField(
            controller: _screenshot,
            keyboardType: TextInputType.url,
            decoration: InputDecoration(labelText: t.screenshotOptional),
          ),
          const SizedBox(height: AppTokens.s24),
          FilledButton(
            onPressed: _submitting ? null : _submit,
            child: _submitting
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : Text(t.submitPayment),
          ),
        ],
      ),
    );
  }

  Widget _planTile(L10n t, Plan p) {
    final selected = p.id == _selectedPlan;
    final label = p.id == 'yearly' ? t.planYearly : t.planMonthly;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTokens.s8),
      child: Material(
        color: selected
            ? AppTokens.primary.withOpacity(0.08)
            : AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rControl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppTokens.rControl),
          onTap: () => setState(() => _selectedPlan = p.id),
          child: Container(
            constraints: const BoxConstraints(minHeight: AppTokens.touchTarget),
            padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.s16, vertical: AppTokens.s12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppTokens.rControl),
              border: Border.all(
                color: selected ? AppTokens.primary : const Color(0xFFD9DCD8),
                width: selected ? 2 : 1,
              ),
            ),
            child: Row(
              children: [
                Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: selected ? AppTokens.primary : AppTokens.textSecondary),
                const SizedBox(width: AppTokens.s12),
                Expanded(
                    child: Text(label,
                        style: Theme.of(context).textTheme.bodyLarge)),
                Text(t.amountEgp(p.amountEgp),
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, color: AppTokens.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PayToCard extends StatelessWidget {
  const _PayToCard({
    required this.displayName,
    required this.ipa,
    required this.onCopy,
  });
  final String displayName;
  final String ipa;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Container(
      padding: const EdgeInsets.all(AppTokens.s16),
      decoration: BoxDecoration(
        color: AppTokens.surface,
        borderRadius: BorderRadius.circular(AppTokens.rTile),
        border: Border.all(color: const Color(0xFFD9DCD8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t.payToLabel, style: Theme.of(context).textTheme.labelSmall),
          const SizedBox(height: AppTokens.s4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(ipa,
                        style: Theme.of(context).textTheme.titleLarge,
                        overflow: TextOverflow.ellipsis),
                    if (displayName.isNotEmpty)
                      Text(displayName,
                          style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
              const SizedBox(width: AppTokens.s8),
              OutlinedButton.icon(
                onPressed: onCopy,
                icon: const Icon(Icons.copy, size: 18),
                label: Text(t.copy),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _UnderReview extends StatelessWidget {
  const _UnderReview({required this.onClose});
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.hourglass_top, size: 48, color: AppTokens.warning),
            const SizedBox(height: AppTokens.s16),
            Text(t.underReview, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppTokens.s8),
            Text(t.underReviewBody, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.s24),
            OutlinedButton(onPressed: onClose, child: Text(t.close)),
          ],
        ),
      ),
    );
  }
}
