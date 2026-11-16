import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/api_config.dart';
import 'package:trendsham/models/coupon_story.dart';

void main() {
  group('StoryModel', () {
    test('uses the active and expiration values from the API', () {
      final story = StoryModel.fromJson({
        'id': 12,
        'image': '/storage/stories/test.jpg',
        'is_active': false,
        'expires_at':
            DateTime.now().add(const Duration(hours: 1)).toIso8601String(),
      });

      expect(story.isActive, isFalse);
      expect(story.isExpired, isFalse);
    });

    test('marks stories with a past expiration as expired', () {
      final story = StoryModel.fromJson({
        'id': 13,
        'image': '/storage/stories/test.jpg',
        'expires_at': DateTime.now()
            .subtract(const Duration(minutes: 1))
            .toIso8601String(),
      });

      expect(story.isExpired, isTrue);
    });

    test('replaces localhost in API image URLs with the configured server', () {
      final story = StoryModel.fromJson({
        'id': 14,
        'image': 'http://localhost/storage/stories/test.jpg',
      });

      expect(
          story.imageUrl, startsWith('${ApiConfig.storageBaseUrl}/storage/'));
      expect(story.imageUrl, endsWith('/storage/stories/test.jpg'));
    });
  });
}
