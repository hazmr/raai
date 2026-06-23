import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

// TODO(build-order §5.3): herd list (cursor pagination) + search by barcode.
class AnimalsScreen extends StatelessWidget {
  const AnimalsScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(title: L10n.of(context).tileHerd);
}
