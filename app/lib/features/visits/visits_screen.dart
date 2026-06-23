import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

// TODO(build-order §5.6): farmer open/close visits; vet open-visits + visit animals.
class VisitsScreen extends StatelessWidget {
  const VisitsScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(title: L10n.of(context).tileOpenVisits);
}
