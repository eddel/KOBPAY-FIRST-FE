import "package:flutter_secure_storage/flutter_secure_storage.dart";

class TokenStorage {
  static const _accessTokenKey = "accessToken";
  static const _refreshTokenKey = "refreshToken";
  static const _biometricsEnabledKey = "biometricsEnabled";
  static const _biometricUnlockKey = "biometricUnlockEnabled";

  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken
  }) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<Map<String, String>?> loadTokens() async {
    final accessToken = await _storage.read(key: _accessTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
    if (accessToken == null || refreshToken == null) {
      return null;
    }
    return {
      "accessToken": accessToken,
      "refreshToken": refreshToken
    };
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }

  Future<void> saveBiometricsEnabled(bool enabled) async {
    await _storage.write(key: _biometricsEnabledKey, value: enabled ? "1" : "0");
  }

  Future<bool?> loadBiometricsEnabled() async {
    final value = await _storage.read(key: _biometricsEnabledKey);
    if (value == null) return null;
    return value == "1";
  }

  Future<void> saveBiometricUnlockEnabled(bool enabled) async {
    await _storage.write(key: _biometricUnlockKey, value: enabled ? "1" : "0");
  }

  Future<bool?> loadBiometricUnlockEnabled() async {
    final value = await _storage.read(key: _biometricUnlockKey);
    if (value == null) return null;
    return value == "1";
  }

  Future<bool> hasRefreshToken() async {
    final value = await _storage.read(key: _refreshTokenKey);
    return value != null && value.isNotEmpty;
  }
}
