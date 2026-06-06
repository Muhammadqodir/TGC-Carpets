import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../constants/app_constants.dart';

abstract class TokenStorage {
  Future<void> saveToken(String token);
  Future<String?> getToken();
  Future<void> deleteToken();
}

class SecureTokenStorage implements TokenStorage {
  final FlutterSecureStorage _storage;

  static const _kTimeout = Duration(seconds: 5);

  const SecureTokenStorage(this._storage);

  @override
  Future<void> saveToken(String token) async {
    try {
      await _storage
          .write(key: AppConstants.tokenKey, value: token)
          .timeout(_kTimeout);
    } catch (_) {
      // Ignore write failures — the user will simply be asked to log in again.
    }
  }

  /// Reads the stored token.
  ///
  /// On Windows the Credential Manager can become corrupted or inaccessible
  /// after a restart, causing [FlutterSecureStorage.read] to hang or throw.
  /// We guard against both with a timeout and a catch-all that deletes the
  /// broken entry so the app can proceed to the login screen instead of
  /// freezing on startup.
  @override
  Future<String?> getToken() async {
    try {
      return await _storage
          .read(key: AppConstants.tokenKey)
          .timeout(_kTimeout);
    } catch (_) {
      await _tryDeleteToken();
      return null;
    }
  }

  @override
  Future<void> deleteToken() async {
    await _tryDeleteToken();
  }

  Future<void> _tryDeleteToken() async {
    try {
      await _storage
          .delete(key: AppConstants.tokenKey)
          .timeout(_kTimeout);
    } catch (_) {
      // Best-effort: nothing we can do if deletion also fails.
    }
  }
}
