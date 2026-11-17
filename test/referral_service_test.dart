import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/referral_service.dart';

void main() {
  test('referral summary reads the API shape', () {
    final s = ReferralSummary.fromJson({
      'code': 'L7QX2',
      'link': 'http://x/invite/L7QX2',
      'share_text': 'Shop with me',
      'reward_points': 25,
      'min_order': 25000,
      'can_apply': true,
      'referred_by': {'name': 'Sam', 'status': 'pending', 'status_label': 'Waiting'},
      'stats': {'joined': 2, 'rewarded': 1, 'points_earned': 25},
      'invited': [
        {'name': 'Ali K', 'status': 'rewarded', 'status_label': 'Rewarded', 'joined_at': '2026-11-17'},
      ],
    });

    expect(s.code, 'L7QX2');
    expect(s.rewardPoints, 25);
    expect(s.minOrder, 25000);
    expect(s.canApply, isTrue);
    expect(s.referredByName, 'Sam');
    expect(s.joined, 2);
    expect(s.pointsEarned, 25);
    expect(s.invited.single.rewarded, isTrue);
  });

  test('missing fields fall back safely', () {
    final s = ReferralSummary.fromJson({});
    expect(s.code, '');
    expect(s.canApply, isFalse);
    expect(s.referredByName, isNull);
    expect(s.invited, isEmpty);
  });
}
