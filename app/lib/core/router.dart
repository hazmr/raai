import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/animals/animals_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/billing/paywall_screen.dart';
import '../features/home/home_screen.dart';
import '../features/scan/scan_screen.dart';
import '../features/visits/visits_screen.dart';
import 'auth/session.dart';

/// One go_router with a single redirect guard (§4):
///   no tokens → /login · logged in → /home · any 402 → /paywall (farmer only).
final routerProvider = Provider<GoRouter>((ref) {
  // Bridge Riverpod → Listenable so the router re-evaluates redirect on changes.
  final refresh = _RefreshNotifier();
  ref.onDispose(refresh.dispose);
  ref.listen(sessionControllerProvider, (_, __) => refresh.bump());
  ref.listen(paywallProvider, (_, __) => refresh.bump());

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    redirect: (context, state) {
      final session = ref.read(sessionControllerProvider);
      final paywall = ref.read(paywallProvider);
      final loc = state.matchedLocation;
      final onAuth = loc == '/login' || loc == '/register';
      final onSplash = loc == '/';

      switch (session.status) {
        case SessionStatus.unknown:
          return onSplash ? null : '/';
        case SessionStatus.loggedOut:
          return onAuth ? null : '/login';
        case SessionStatus.loggedIn:
          if (onSplash || onAuth) return '/home';
          // Vets have no paywall; farmers get routed to it on any 402.
          if (session.isVet && loc == '/paywall') return '/home';
          if (session.isFarmer && paywall && loc != '/paywall') return '/paywall';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/animals', builder: (_, __) => const AnimalsScreen()),
      GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(path: '/visits', builder: (_, __) => const VisitsScreen()),
      GoRoute(path: '/paywall', builder: (_, __) => const PaywallScreen()),
    ],
  );
});

class _RefreshNotifier extends ChangeNotifier {
  void bump() => notifyListeners();
}

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
