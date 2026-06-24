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

/// Set by the dio interceptor on any 402; the router redirects farm admins to /paywall.
final paywallProvider = StateProvider<bool>((ref) => false);

/// --- session state ---

enum SessionStatus { unknown, loggedOut, loggedIn }

class SessionState {
  const SessionState(this.status, {this.kind, this.farmRole, this.farmName});
  final SessionStatus status;
  final String? kind; // user | doctor
  final String? farmRole; // admin | farmer | doctor
  final String? farmName;

  bool get isDoctor => kind == 'doctor';
  bool get isAdmin => farmRole == 'admin';
  bool get isFarmer => farmRole == 'farmer';
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
    state = SessionState(
      SessionStatus.loggedIn,
      kind: await _store.readKind() ?? 'user',
      farmRole: await _store.readFarmRole() ?? 'farmer',
      farmName: await _store.readFarmName(),
    );
  }

  Future<void> login(String phone, String password) async {
    final tokens = await _api.login(phone, password);
    await _store.saveUser(access: tokens.accessToken, refresh: tokens.refreshToken);
    final me = await _api.me();
    await _store.saveProfile(farmRole: me.farmRole, farmName: me.farm.name);
    _resetPaywall();
    state = SessionState(SessionStatus.loggedIn,
        kind: 'user', farmRole: me.farmRole, farmName: me.farm.name);
  }

  /// Self-registration creates a farm; the user becomes its admin.
  Future<void> register(String phone, String password, String farmName) async {
    final tokens = await _api.register(phone, password, farmName);
    await _store.saveUser(
        access: tokens.accessToken,
        refresh: tokens.refreshToken,
        farmRole: 'admin',
        farmName: farmName);
    _resetPaywall();
    state = SessionState(SessionStatus.loggedIn,
        kind: 'user', farmRole: 'admin', farmName: farmName);
  }

  /// Doctor enters with a scanned QR invite secret — no account.
  Future<void> redeemDoctor(String inviteToken) async {
    final sess = await _api.redeemDoctor(inviteToken);
    await _store.saveDoctor(
      access: sess.accessToken,
      inviteToken: inviteToken,
      farmName: sess.farm.name,
      doctorLabel: sess.doctorLabel,
    );
    _resetPaywall();
    state = SessionState(SessionStatus.loggedIn,
        kind: 'doctor', farmRole: 'doctor', farmName: sess.farm.name);
  }

  Future<void> logout() async {
    if (!state.isDoctor) {
      try {
        await _api.logout();
      } catch (_) {/* best-effort */}
    }
    await _store.clear();
    _resetPaywall();
    state = const SessionState(SessionStatus.loggedOut);
  }

  Future<void> onExpired() async {
    await _store.clear();
    _resetPaywall();
    state = const SessionState(SessionStatus.loggedOut);
  }

  void _resetPaywall() => ref.read(paywallProvider.notifier).state = false;
}

final sessionControllerProvider =
    NotifierProvider<SessionController, SessionState>(SessionController.new);
