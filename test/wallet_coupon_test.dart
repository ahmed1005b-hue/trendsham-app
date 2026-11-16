import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/wallet_coupon.dart';
import 'package:trendsham/services/checkout_service.dart';

void main() {
  test('كوبون المحفظة يقرأ القيمة والمصدر والتوفير', () {
    final c = WalletCoupon.fromJson({
      'id': 7,
      'title': 'خصم الترحيب',
      'type': 'percentage',
      'value_label': 'خصم 15%',
      'source_label': 'من تريندشام',
      'funder': 'platform',
      'min_order_amount': 100000,
      'status': 'available',
      'expires_at': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      'ok': true,
      'saving': 15000,
    });

    expect(c.id, 7);
    expect(c.valueLabel, 'خصم 15%');
    expect(c.isSeller, isFalse);
    expect(c.ok, isTrue);
    expect(c.saving, 15000);
    expect(c.expiresSoon, isTrue);
  });

  test('كوبون غير صالح يحمل السبب', () {
    final c = WalletCoupon.fromJson({
      'id': 1,
      'title': 'x',
      'type': 'fixed',
      'value_label': 'خصم 5,000 ل.س',
      'funder': 'seller',
      'status': 'available',
      'ok': false,
      'reason': 'أضف 20,000 ل.س لتستفيد',
    });

    expect(c.isSeller, isTrue);
    expect(c.ok, isFalse);
    expect(c.reason, 'أضف 20,000 ل.س لتستفيد');
    expect(c.expiresSoon, isFalse);
  });

  test('ملخص الدفع يقرأ الكوبون المطبق والخيارات', () {
    final s = CheckoutSummary.fromJson({
      'subtotal': 100000,
      'shipping_fee': 0,
      'base_shipping_fee': 150,
      'discount': 20000,
      'total': 80000,
      'coupon': {'id': 3, 'title': 'a', 'type': 'fixed', 'value_label': 'v', 'status': 'available', 'ok': true, 'saving': 20150},
      'coupon_auto': true,
      'coupon_options': [
        {'id': 3, 'title': 'a', 'type': 'fixed', 'value_label': 'v', 'status': 'available', 'ok': true, 'saving': 20150},
        {'id': 4, 'title': 'b', 'type': 'fixed', 'value_label': 'v', 'status': 'available', 'ok': false, 'reason': 'r'},
      ],
      'currency': 'SYP',
    });

    expect(s.coupon?.id, 3);
    expect(s.couponAuto, isTrue);
    expect(s.couponOptions, hasLength(2));
    expect(s.baseShippingFee, 150);
    expect(s.couponValid, isTrue);
    expect(s.couponDroppedReason, isNull);
  });

  test('ملخص الدفع يخبر لماذا سقط الكوبون المختار', () {
    final s = CheckoutSummary.fromJson({
      'subtotal': 100000,
      'shipping_fee': 150,
      'discount': 0,
      'total': 100150,
      'coupon': null,
      'coupon_dropped_reason': 'استُخدم في طلب سابق',
      'coupon_options': [],
    });

    expect(s.coupon, isNull);
    expect(s.couponDroppedReason, 'استُخدم في طلب سابق');
  });
}
