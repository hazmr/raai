import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Tokens kept off plain prefs (§5.1). Two principal kinds:
///   - user  : access + refresh tokens (rotated via /auth/refresh).
///   - doctor: access token + the invite secret (re-redeemed via /doctor/redeem
///             when the access token expires; an ended invite makes that fail).
class TokenStore {
  TokenStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kKind = 'kind'; // user | doctor
  static const _kFarmRole = 'farm_role'; // admin | farmer | doctor
  static const _kFarmName = 'farm_name';
  static const _kInviteToken = 'invite_token';
  static const _kDoctorLabel = 'doctor_label';

  Future<String?> readAccess() => _storage.read(key: _kAccess);
  Future<String?> readRefresh() => _storage.read(key: _kRefresh);
  Future<String?> readKind() => _storage.read(key: _kKind);
  Future<String?> readFarmRole() => _storage.read(key: _kFarmRole);
  Future<String?> readFarmName() => _storage.read(key: _kFarmName);
  Future<String?> readInviteToken() => _storage.read(key: _kInviteToken);
  Future<String?> readDoctorLabel() => _storage.read(key: _kDoctorLabel);

  Future<void> saveUser({
    required String access,
    required String refresh,
    String? farmRole,
    String? farmName,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kRefresh, value: refresh);
    await _storage.write(key: _kKind, value: 'user');
    if (farmRole != null) await _storage.write(key: _kFarmRole, value: farmRole);
    if (farmName != null) await _storage.write(key: _kFarmName, value: farmName);
  }

  Future<void> saveDoctor({
    required String access,
    required String inviteToken,
    required String farmName,
    required String doctorLabel,
  }) async {
    await _storage.write(key: _kAccess, value: access);
    await _storage.write(key: _kInviteToken, value: inviteToken);
    await _storage.write(key: _kKind, value: 'doctor');
    await _storage.write(key: _kFarmRole, value: 'doctor');
    await _storage.write(key: _kFarmName, value: farmName);
    await _storage.write(key: _kDoctorLabel, value: doctorLabel);
  }

  /// Updates just the access token after a refresh / re-redeem.
  Future<void> saveAccess(String access) => _storage.write(key: _kAccess, value: access);

  Future<void> saveProfile({String? farmRole, String? farmName}) async {
    if (farmRole != null) await _storage.write(key: _kFarmRole, value: farmRole);
    if (farmName != null) await _storage.write(key: _kFarmName, value: farmName);
  }

  Future<void> clear() async {
    for (final k in [_kAccess, _kRefresh, _kKind, _kFarmRole, _kFarmName, _kInviteToken, _kDoctorLabel]) {
      await _storage.delete(key: k);
    }
  }

  Future<bool> get hasSession async => (await readAccess()) != null;
}
