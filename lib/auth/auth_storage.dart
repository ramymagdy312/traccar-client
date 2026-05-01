import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _keyAccessToken = 'auth_access_token';
  static const _keyTokenExpiryEpochMs = 'auth_token_expiry_epoch_ms';
  static const _keyLoginEpochMs = 'auth_login_epoch_ms';

  // Legacy keys that earlier builds wrote. They must be purged on upgrade so
  // credentials never linger on disk after this change.
  static const _legacyKeyUsername = 'auth_username';
  static const _legacyKeyPassword = 'auth_password';
  static const _legacyKeyRefreshToken = 'auth_refresh_token';

  final FlutterSecureStorage _secureStorage;

  const AuthStorage({
    FlutterSecureStorage secureStorage = const FlutterSecureStorage(),
  }) : _secureStorage = secureStorage;

  Future<String?> readAccessToken() =>
      _secureStorage.read(key: _keyAccessToken);

  Future<void> writeAccessToken(String token) =>
      _secureStorage.write(key: _keyAccessToken, value: token);

  Future<void> writeTokenExpiryEpochMs(int epochMs) => _secureStorage.write(
    key: _keyTokenExpiryEpochMs,
    value: epochMs.toString(),
  );

  Future<int?> readTokenExpiryEpochMs() async {
    final raw = await _secureStorage.read(key: _keyTokenExpiryEpochMs);
    return int.tryParse(raw ?? '');
  }

  Future<void> writeLoginEpochMs(int epochMs) =>
      _secureStorage.write(key: _keyLoginEpochMs, value: epochMs.toString());

  Future<int?> readLoginEpochMs() async {
    final raw = await _secureStorage.read(key: _keyLoginEpochMs);
    return int.tryParse(raw ?? '');
  }

  Future<void> clear() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyTokenExpiryEpochMs);
    await _secureStorage.delete(key: _keyLoginEpochMs);
  }

  Future<bool> hasActiveSessionToken() async {
    final token = await readAccessToken();
    return token != null && token.isNotEmpty;
  }

  Future<void> clearAll() async {
    await clear();
    await purgeLegacyCredentials();
  }

  /// Delete any credentials that older versions of the app may have stored.
  /// Safe to call at any time; idempotent.
  Future<void> purgeLegacyCredentials() async {
    await _secureStorage.delete(key: _legacyKeyUsername);
    await _secureStorage.delete(key: _legacyKeyPassword);
    await _secureStorage.delete(key: _legacyKeyRefreshToken);
  }
}
