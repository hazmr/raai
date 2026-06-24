import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/animals/add_animal_screen.dart';
import '../features/animals/animal_detail_screen.dart';
import '../features/animals/animals_screen.dart';
import '../features/auth/doctor_redeem_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/billing/paywall_screen.dart';
import '../features/farm/members_screen.dart';
import '../features/home/home_screen.dart';
import '../features/invites/invites_screen.dart';
import '../features/scan/scan_screen.dart';
import 'api/models.dart';
import 'auth/session.dart';

/// Routes only the farm admin may reach.
const _adminOnly = {'/members', '/invites', '/paywall'};

/// One go_router with a single redirect guard. Entry paths: phone login/register
/// (members) and the doctor QR redeem. Doctors and plain farmers can't reach the
/// admin-only routes; a 402 routes the admin to /paywall.
final routerProvider = Provider<GoRouter>((ref) {
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
      final onAuth = loc == '/login' || loc == '/register' || loc == '/doctor';
      final onSplash = loc == '/';

      switch (session.status) {
        case SessionStatus.unknown:
          return onSplash ? null : '/';
        case SessionStatus.loggedOut:
          return onAuth ? null : '/login';
        case SessionStatus.loggedIn:
          if (onSplash || onAuth) return '/home';
          // Only the farm admin may reach billing / member / invite management.
          if (_adminOnly.contains(loc) && !session.isAdmin) return '/home';
          // Lapsed farm → push the admin to the paywall.
          if (session.isAdmin && paywall && loc != '/paywall') return '/paywall';
          return null;
      }
    },
    routes: [
      GoRoute(path: '/', builder: (_, __) => const _Splash()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),
      GoRoute(path: '/doctor', builder: (_, __) => const DoctorRedeemScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(path: '/animals', builder: (_, __) => const AnimalsScreen()),
      // `/animals/new` must precede `/animals/:id` so "new" isn't read as an id.
      GoRoute(
        path: '/animals/new',
        builder: (_, state) => AddAnimalScreen(initialBarcode: state.extra as String?),
      ),
      GoRoute(
        path: '/animals/:id',
        builder: (_, state) => AnimalDetailScreen(
          animalId: int.parse(state.pathParameters['id']!),
          initial: state.extra as Animal?,
        ),
      ),
      GoRoute(path: '/scan', builder: (_, __) => const ScanScreen()),
      GoRoute(path: '/members', builder: (_, __) => const MembersScreen()),
      GoRoute(path: '/invites', builder: (_, __) => const InvitesScreen()),
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
