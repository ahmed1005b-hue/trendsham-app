import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/services/checkout_service.dart';
import 'package:trendsham/services/loyalty_service.dart';

void main() {
  test('parses loyalty summary with expiring points', () {
    final s = LoyaltySummary.fromJson({
      'enabled': true,
      'balance': 30,
      'balance_value': 6000,
      'pending': 4,
      'debt': 0,
      'point_value': 200,
      'spend_per_point': 10000,
      'min_redeem': 10,
      'coupon_valid_days': 30,
      'expiring_soon': {'points': 12, 'expires_at': '2026-12-05'},
    });
    expect(s.balance, 30);
    expect(s.balanceValue, 6000);
    expect(s.canRedeem, isTrue);
    expect(s.expiringPoints, 12);
    expect(s.expiringAt, '2026-12-05');
  });

  test('cannot redeem below minimum or when disabled', () {
    Map<String, dynamic> j(bool enabled, int balance) => {
          'enabled': enabled, 'balance': balance, 'min_redeem': 10,
          'point_value': 200, 'spend_per_point': 10000,
        };
    expect(LoyaltySummary.fromJson(j(true, 9)).canRedeem, isFalse);
    expect(LoyaltySummary.fromJson(j(false, 50)).canRedeem, isFalse);
  });

  test('parses transactions page and next page', () {
    final p = LoyaltyPage.fromJson({
      'data': [
        {'id': 1, 'type': 'earn', 'label': 'من الطلب TS-1', 'points': 4, 'order_number': 'TS-1', 'expires_at': '2027-11-12', 'created_at': '2026-11-12T10:00:00Z'},
        {'id': 2, 'type': 'redeem_coupon', 'label': 'تحويل إلى كوبون', 'points': -20},
      ],
      'next_page': 2,
    });
    expect(p.items.length, 2);
    expect(p.items.first.points, 4);
    expect(p.items.last.points, -20);
    expect(p.nextPage, 2);
  });

  test('checkout summary carries loyalty block', () {
    final s = CheckoutSummary.fromJson({
      'subtotal': 50000, 'shipping_fee': 150, 'discount': 0, 'total': 50150,
      'loyalty': {'enabled': true, 'balance': 30, 'max_usable': 30, 'point_value': 200, 'min_redeem': 10, 'will_earn': 5, 'spend_per_point': 10000},
    });
    expect(s.loyalty, isNotNull);
    expect(s.loyalty!.usable, isTrue);
    expect(s.loyalty!.maxUsable * s.loyalty!.pointValue, 6000);
  });

  test('product reads will_earn_points', () {
    final p = Product.fromJson({'id': 1, 'name': 'x', 'slug': 'x', 'price': 35000, 'will_earn_points': 3});
    expect(p.willEarnPoints, 3);
  });

  test('points label grammar', () {
    expect(pointsLabel(1), 'نقطة واحدة');
    expect(pointsLabel(2), 'نقطتين');
    expect(pointsLabel(5), '5 نقاط');
    expect(pointsLabel(12), '12 نقطة');
  });
}
