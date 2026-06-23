import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

// TODO(build-order §5.7): plans + IPA copy button → submit reference → poll status.
class PaywallScreen extends StatelessWidget {
  const PaywallScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(title: L10n.of(context).tileSubscription);
}
