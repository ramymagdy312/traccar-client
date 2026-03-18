import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthStorage {
  static const _keyAccessToken = 'auth_access_token';

  final FlutterSecureStorage _secureStorage;

  const AuthStorage({FlutterSecureStorage secureStorage = const FlutterSecureStorage()})
    : _secureStorage = secureStorage;

  Future<String?> readAccessToken() => _secureStorage.read(key: _keyAccessToken);

  Future<void> writeAccessToken(String token) => _secureStorage.write(
    key: _keyAccessToken,
    value: token,
  );

  Future<void> clear() => _secureStorage.delete(key: _keyAccessToken);
}

