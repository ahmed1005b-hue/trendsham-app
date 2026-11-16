import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/notification_settings_service.dart';
import 'package:trendsham/services/store_service.dart';

void main() {
  final json = {
    'role': 'customer',
    'groups': [
      {
        'key': 'orders',
        'label': 'الطلبات والدفع والشحن',
        'description': 'تأكيد الطلب، الشحن، التسليم، الدفع',
        'enabled': true,
        'locked': false,
      },
      {
        'key': 'offers',
        'label': 'العروض والمنتجات الجديدة',
        'description': 'من المتاجر التي تتابعها',
        'enabled': null,
        'locked': false,
      },
    ],
    'always_on_note': 'إشعارات الأمان والمال المهمة تصلك دائماً.',
    'offers_prompted': false,
  };

  test('parses groups, undecided offers counts as off', () {
    final s = NotificationSettings.fromJson(json);
    expect(s.role, 'customer');
    expect(s.groups.length, 2);
    expect(s.groups.first.key, 'orders');
    expect(s.groups.first.enabled, isTrue);
    expect(s.groups.last.enabled, isFalse);
    expect(s.groups.last.undecided, isTrue);
    expect(s.alwaysOnNote, contains('دائماً'));
    expect(s.offersPrompted, isFalse);
  });

  test('copyWith toggles one group only', () {
    final s = NotificationSettings.fromJson(json);
    final updated = s.withGroup('offers', true);
    expect(updated.groups.last.enabled, isTrue);
    expect(updated.groups.last.undecided, isFalse);
    expect(updated.groups.first.enabled, isTrue);
    expect(s.groups.last.enabled, isFalse); // الأصل لا يتغير
  });

  test('follow result carries the ask-about-offers flag', () {
    final first = FollowResult.fromJson({'followed': true, 'ask_offers_opt_in': true});
    expect(first.followed, isTrue);
    expect(first.askOffersOptIn, isTrue);
    final old = FollowResult.fromJson({'followed': false});
    expect(old.askOffersOptIn, isFalse);
  });
}
