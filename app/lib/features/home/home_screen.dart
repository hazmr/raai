import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/theme.dart';
import '../../l10n/app_localizations.dart';
import 'home_providers.dart';

/// Bento home — the only "designed" screen (§1.2). Renders the farmer or vet grid.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final session = ref.watch(sessionControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(t.appTitle),
        actions: [
          IconButton(
            tooltip: t.logout,
            onPressed: () => ref.read(sessionControllerProvider.notifier).logout(),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppTokens.s16),
          child: session.isVet ? const _VetGrid() : const _FarmerGrid(),
        ),
      ),
    );
  }
}

class _FarmerGrid extends ConsumerWidget {
  const _FarmerGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final herd = ref.watch(herdSummaryProvider);
    final billing = ref.watch(billingStatusProvider);

    return Column(
      children: [
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: BentoTile(
                  icon: Icons.pets,
                  title: t.tileHerd,
                  subtitle: herd.maybeWhen(
                    data: (s) => t.herdCount(s.count),
                    orElse: () => null,
                  ),
                  onTap: () => context.go('/animals'),
                ),
              ),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  children: [
                    Expanded(
                      child: BentoTile(
                        icon: Icons.qr_code_scanner,
                        title: t.tileScan,
                        onTap: () => context.go('/scan'),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s12),
                    Expanded(
                      child: BentoTile(
                        icon: Icons.add_circle_outline,
                        title: t.tileNewVisit,
                        onTap: () => context.go('/visits'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        _SubscriptionTile(status: billing),
      ],
    );
  }
}

class _VetGrid extends StatelessWidget {
  const _VetGrid();

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Column(
      children: [
        Expanded(
          flex: 2,
          child: BentoTile(
            icon: Icons.event_available,
            title: t.tileOpenVisits,
            onTap: () => context.go('/visits'),
          ),
        ),
        const SizedBox(height: AppTokens.s12),
        Expanded(
          child: BentoTile(
            icon: Icons.qr_code_scanner,
            title: t.tileScan,
            onTap: () => context.go('/scan'),
          ),
        ),
      ],
    );
  }
}

class _SubscriptionTile extends StatelessWidget {
  const _SubscriptionTile({required this.status});
  final AsyncValue<BillingStatus> status;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return status.maybeWhen(
      data: (s) {
        final (color, label) = switch (s.status) {
          'active' => (AppTokens.success, t.subscriptionActive),
          'pending' => (AppTokens.warning, t.subscriptionActive),
          _ => (AppTokens.error, t.subscriptionLapsed),
        };
        return BentoTile(
          icon: s.isActive ? Icons.verified : Icons.lock_outline,
          title: label,
          subtitle: s.currentPeriodEnd != null
              ? t.renewsOn('${s.currentPeriodEnd!.toLocal()}'.split(' ').first)
              : null,
          color: color,
          compact: true,
          onTap: () => context.go('/paywall'),
        );
      },
      orElse: () => BentoTile(
        icon: Icons.workspace_premium_outlined,
        title: t.tileSubscription,
        compact: true,
        onTap: () => context.go('/paywall'),
      ),
    );
  }
}

/// A single bento tile: large rounded surface, big icon + label, huge touch target.
class BentoTile extends StatelessWidget {
  const BentoTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.onTap,
    this.color,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Color? color;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = color ?? AppTokens.primary;
    return Material(
      color: AppTokens.surface,
      borderRadius: BorderRadius.circular(AppTokens.rTile),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTokens.rTile),
        child: Container(
          constraints: const BoxConstraints(minHeight: AppTokens.touchTarget),
          padding: const EdgeInsets.all(AppTokens.s16),
          child: Row(
            mainAxisAlignment: compact ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(icon, size: compact ? 28 : 40, color: fg),
              const SizedBox(width: AppTokens.s12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleLarge),
                    if (subtitle != null)
                      Text(subtitle!, style: Theme.of(context).textTheme.labelSmall),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
