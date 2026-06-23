import 'package:flutter/material.dart';

import '../../core/widgets/coming_soon.dart';
import '../../l10n/app_localizations.dart';

// TODO(build-order §5.4): mobile_scanner → GET /animals?barcode= → open or create.
class ScanScreen extends StatelessWidget {
  const ScanScreen({super.key});

  @override
  Widget build(BuildContext context) => ComingSoon(title: L10n.of(context).tileScan);
}
