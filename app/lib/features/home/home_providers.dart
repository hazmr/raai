import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/auth/session.dart';
import '../../core/sync/providers.dart';

/// Current subscription state for the farmer's subscription tile (§5.2).
final billingStatusProvider = FutureProvider.autoDispose<BillingStatus>((ref) {
  return ref.watch(apiProvider).billingStatus();
});

class HerdSummary {
  const HerdSummary(this.count);
  final int count;
}

/// The herd size for the home tile, counted in the local cache so the number is
/// there the moment the app opens — with or without signal.
final herdSummaryProvider = StreamProvider.autoDispose<HerdSummary>((ref) {
  return ref
      .watch(herdRepositoryProvider)
      .watchAnimals()
      .map((animals) => HerdSummary(animals.length));
});
