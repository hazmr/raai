import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens kept off plain prefs (§5.1). Access token is attached to every request;
/// refresh token is used to rotate when the access token expires.
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kRole = 'role';

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  Future<String?> readRole() => _storage.read(key: _kRole);

  Future<void> save({
    required String access,
    required String refresh,
    String? role,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    if (role != null) await _storage.write(key: _kRole, value: role);
  }

  Future<void> saveRole(String role) => _storage.write(key: _kRole, value: role);

  Future<void> clear() async {
    await _storage.delete(key: _kAccess);
    await _storage.delete(key: _kRefresh);
    await _storage.delete(key: _kRole);
  }

  Future<bool> get hasSession async => (await readAccess()) != null;
}
