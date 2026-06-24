import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme.dart';

/// Full-screen "couldn't load" state with a Retry (§6.3). Reads should prefer
/// cached data; this is the fallback when there's nothing to show.
class ErrorRetry extends StatelessWidget {
  const ErrorRetry({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final t = L10n.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppTokens.s24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off, size: 40, color: AppTokens.textSecondary),
            const SizedBox(height: AppTokens.s12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: AppTokens.s16),
            FilledButton(onPressed: onRetry, child: Text(t.retry)),
          ],
        ),
      ),
    );
  }
}

/// A plain, centered empty-state line. Wrapped in a scrollable so it still works
/// inside a RefreshIndicator.
class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message, this.icon});
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        const SizedBox(height: 120),
        if (icon != null) ...[
          Icon(icon, size: 40, color: AppTokens.textSecondary),
          const SizedBox(height: AppTokens.s12),
        ],
        Center(
          child: Text(message,
              style: const TextStyle(color: AppTokens.textSecondary)),
        ),
      ],
    );
  }
}
