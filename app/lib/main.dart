import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router.dart';
import 'core/theme.dart';
import 'l10n/app_localizations.dart';

void main() {
  runApp(const ProviderScope(child: RaaiApp()));
}

class RaaiApp extends ConsumerWidget {
  const RaaiApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      onGenerateTitle: (context) => L10n.of(context).appTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      routerConfig: router,

      // Arabic is the default locale; English optional (§8). RTL flips automatically.
      locale: const Locale('ar'),
      localizationsDelegates: L10n.localizationsDelegates,
      supportedLocales: L10n.supportedLocales,
    );
  }
}
