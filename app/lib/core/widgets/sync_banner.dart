import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../sync/providers.dart';
import '../theme.dart';
import '../../l10n/app_localizations.dart';

/// A thin strip that appears only when the outbox is not empty (§7).
///
/// Queued writes are normal in the field, so this states the fact plainly rather
/// than raising an alarm; writes the server refused get a Retry.
class SyncBanner extends ConsumerWidget {
  const SyncBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = L10n.of(context);
    final pending = ref.watch(pendingWritesProvider).value ?? 0;
    final failed = ref.watch(failedWritesProvider).value ?? 0;
    if (pending == 0 && failed == 0) return const SizedBox.shrink();

    final isFailure = failed > 0;
    final color = isFailure ? AppTokens.error : AppTokens.textSecondary;
    return Container(
      width: double.infinity,
      color: color.withValues(alpha: 0.08),
      padding: const EdgeInsets.symmetric(
          horizontal: AppTokens.s16, vertical: AppTokens.s8),
      child: Row(
        children: [
          Icon(isFailure ? Icons.error_outline : Icons.cloud_upload_outlined,
              size: 16, color: color),
          const SizedBox(width: AppTokens.s8),
          Expanded(
            child: Text(
              isFailure ? t.failedWrites(failed) : t.pendingWrites(pending),
              style: TextStyle(fontSize: 12, color: color),
            ),
          ),
          TextButton(
            onPressed: () => isFailure
                ? ref.read(syncServiceProvider).retryFailed()
                : ref.read(syncServiceProvider).drain(),
            child: Text(isFailure ? t.retry : t.syncNow),
          ),
        ],
      ),
    );
  }
}
