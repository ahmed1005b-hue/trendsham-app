import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/services/auth_token_storage.dart';

class _MemorySecureStorage implements SecureStringStorage {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AuthTokenStorage', () {
    late _MemorySecureStorage secureStorage;
    late AuthTokenStorage tokenStorage;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      secureStorage = _MemorySecureStorage();
      tokenStorage = AuthTokenStorage(secureStorage: secureStorage);
    });

    test('migrates a legacy token to secure storage', () async {
      SharedPreferences.setMockInitialValues({
        AuthTokenStorage.tokenKey: 'legacy-token',
      });

      expect(await tokenStorage.read(), 'legacy-token');
      expect(
        secureStorage.values[AuthTokenStorage.tokenKey],
        'legacy-token',
      );
      expect(
        (await SharedPreferences.getInstance())
            .containsKey(AuthTokenStorage.tokenKey),
        isFalse,
      );
    });

    test('removes a stale legacy token when secure storage has a token',
        () async {
      secureStorage.values[AuthTokenStorage.tokenKey] = 'secure-token';
      SharedPreferences.setMockInitialValues({
        AuthTokenStorage.tokenKey: 'old-token',
      });

      expect(await tokenStorage.read(), 'secure-token');
      expect(
        (await SharedPreferences.getInstance())
            .containsKey(AuthTokenStorage.tokenKey),
        isFalse,
      );
    });

    test('deletes tokens from secure and legacy storage', () async {
      secureStorage.values[AuthTokenStorage.tokenKey] = 'secure-token';
      SharedPreferences.setMockInitialValues({
        AuthTokenStorage.tokenKey: 'legacy-token',
      });

      await tokenStorage.delete();

      expect(secureStorage.values, isEmpty);
      expect(
        (await SharedPreferences.getInstance())
            .containsKey(AuthTokenStorage.tokenKey),
        isFalse,
      );
    });
  });
}
