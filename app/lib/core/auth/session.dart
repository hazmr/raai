import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../api/api.dart';
import '../api/dio_client.dart';
import 'token_store.dart';

/// --- wiring providers ---

final tokenStoreProvider = Provider<TokenStore>((ref) => TokenStore());

final dioClientProvider = Provider<DioClient>((ref) {
  final tokens = ref.watch(tokenStoreProvider);
  return DioClient(
    tokens: tokens,
    onSessionExpired: () => ref.read(sessionControllerProvider.notifier).onExpired(),
    onPaywallRequired: () => ref.read(paywallProvider.notifier).state = true,
  );
});

final apiProvider = Provider<RaaiApi>((ref) => RaaiApi(ref.watch(dioClientProvider)));

/// Set by the dio interceptor on any 402; the router redirects farmers to /paywall.
final paywallProvider = StateProvider<bool>((ref) => false);

/// --- session state ---

enum SessionStatus { unknown, loggedOut, loggedIn }

class SessionState {
  const SessionState(this.status, [this.role]);
  final SessionStatus status;
  final String? role; // farmer | vet

  bool get isFarmer => role == 'farmer';
  bool get isVet => role == 'vet';
}

class SessionController extends Notifier<SessionState> {
  @override
  SessionState build() {
    _bootstrap();
    return const SessionState(SessionStatus.unknown);
  }

  TokenStore get _store => ref.read(tokenStoreProvider);
  RaaiApi get _api => ref.read(apiProvider);

  Future<void> _bootstrap() async {
    if (!await _store.hasSession) {
      state = const SessionState(SessionStatus.loggedOut);
      return;
    }
    // Trust the stored role for an instant start (works offline); a later /me
    // call in the app can refresh it if needed.
    final role = await _store.readRole() ?? 'farmer';
    state = SessionState(SessionStatus.loggedIn, role);
  }

  Future<void> login(String phone, String password) async {
    final tokens = await _api.login(phone, password);
    await _store.save(access: tokens.accessToken, refresh: tokens.refreshToken);
    final me = await _api.me();
    await _store.saveRole(me.role);
    _resetPaywall();
    state = SessionState(SessionStatus.loggedIn, me.role);
  }

  Future<void> register(String phone, String password, String role) async {
    final tokens = await _api.register(phone, password, role);
    await _store.save(access: tokens.accessToken, refresh: tokens.refreshToken, role: role);
    _resetPaywall();
    state = SessionState(SessionStatus.loggedIn, role);
  }

  Future<void> logout() async {
    try {
      await _api.logout();
    } catch (_) {
      // best-effort; we clear locally regardless
    }
    await _store.clear();
    _resetPaywall();
    state = const SessionState(SessionStatus.loggedOut);
  }

  /// Called by the dio interceptor when refresh fails (§6.2).
  Future<void> onExpired() async {
    await _store.clear();
    _resetPaywall();
    state = const SessionState(SessionStatus.loggedOut);
  }

  void _resetPaywall() => ref.read(paywallProvider.notifier).state = false;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
