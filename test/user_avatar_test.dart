import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/api_config.dart';
import 'package:trendsham/models/user.dart';

void main() {
  group('AppUser avatar URL', () {
    AppUser userWithAvatar(String avatar) => AppUser(
          id: 1,
          name: 'Test User',
          firstName: 'Test',
          lastName: 'User',
          phone: '0999999999',
          avatar: avatar,
          role: 'customer',
        );

    test('builds a storage URL from a relative avatar path', () {
      expect(
        userWithAvatar('avatars/test.jpg').avatarUrl,
        '${ApiConfig.storageBaseUrl}/storage/avatars/test.jpg',
      );
    });

    test('rewrites localhost URLs to the configured server', () {
      expect(
        userWithAvatar('http://localhost/storage/avatars/test.jpg').avatarUrl,
        '${ApiConfig.storageBaseUrl}/storage/avatars/test.jpg',
      );
    });
  });
}
