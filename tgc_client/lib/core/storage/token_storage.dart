import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

abstract class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
}

class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _storage;

  const SecureTokenStorage(this._storage);

  @override
  Future<void> saveToken(String token) =>
      _storage.write(key: AppConstants.tokenKey, value: token);

  @override
  Future<String?> getToken() =>
      _storage.read(key: AppConstants.tokenKey);

  @override
  Future<void> deleteToken() =>
      _storage.delete(key: AppConstants.tokenKey);
}
