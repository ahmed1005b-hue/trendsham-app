import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract interface class SecureStringStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

class FlutterSecureStringStorage implements SecureStringStorage {
  const FlutterSecureStringStorage();

  static const FlutterSecureStorage _storage = FlutterSecureStorage();

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

class AuthTokenStorage {
  AuthTokenStorage({SecureStringStorage? secureStorage})
      : _secureStorage = secureStorage ?? const FlutterSecureStringStorage();

  static const tokenKey = 'auth_token';
  final SecureStringStorage _secureStorage;

  Future<String?> read() async {
    final secureToken = await _secureStorage.read(tokenKey);
    final preferences = await SharedPreferences.getInstance();
    final legacyToken = preferences.getString(tokenKey);

    if (secureToken != null && secureToken.isNotEmpty) {
      if (legacyToken != null) await preferences.remove(tokenKey);
      return secureToken;
    }

    if (legacyToken == null || legacyToken.isEmpty) return null;

    await _secureStorage.write(tokenKey, legacyToken);
    await preferences.remove(tokenKey);
    return legacyToken;
  }

  Future<void> write(String token) async {
    await _secureStorage.write(tokenKey, token);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(tokenKey);
  }

  Future<void> delete() async {
    await _secureStorage.delete(tokenKey);
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(tokenKey);
  }
}
