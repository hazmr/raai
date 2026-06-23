import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api/models.dart';
import '../../core/auth/session.dart';

/// Current subscription state for the farmer's subscription tile (§5.2).
final billingStatusProvider = FutureProvider.autoDispose<BillingStatus>((ref) {
  return ref.watch(apiProvider).billingStatus();
});

class HerdSummary {
  const HerdSummary(this.count, this.hasMore);
  final int count;
  final bool hasMore;
}

/// A cheap herd summary for the home tile. (A dedicated count endpoint can replace
/// this later; for now we show the first page's size.)
final herdSummaryProvider = FutureProvider.autoDispose<HerdSummary>((ref) async {
  final page = await ref.watch(apiProvider).animals(limit: 50);
  return HerdSummary(page.data.length, page.nextCursor != null);
});
