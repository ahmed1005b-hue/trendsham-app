import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/store_coupon.dart';

void main() {
  test('parses store coupon in every state', () {
    for (final state in ['collectable', 'collected', 'sold_out', 'login_required']) {
      final c = StoreCoupon.fromJson({
        'id': 41,
        'title': 'خصم الافتتاح',
        'type': 'percentage',
        'value_label': 'خصم 10% حتى 20,000 ل.س',
        'min_order_amount': 50000,
        'ends_at': '2026-11-26',
        'scope_label': 'كل منتجات المتجر',
        'remaining': 63,
        'state': state,
      });
      expect(c.state, state);
      expect(c.canCollect, state == 'collectable' || state == 'login_required');
    }
  });

  test('short value and copyWith', () {
    final c = StoreCoupon.fromJson({'id': 1, 'type': 'percentage', 'value_label': 'خصم 10% حتى 20,000 ل.س', 'remaining': 3});
    expect(c.shortValue, '10%');
    expect(c.copyWith(state: 'collected', remaining: 2).remaining, 2);
    expect(StoreCoupon.fromJson({'id': 2, 'type': 'free_shipping', 'value_label': 'شحن مجاني'}).shortValue, 'شحن مجاني');
    expect(StoreCoupon.fromJson({'id': 3, 'type': 'fixed', 'value_label': 'خصم 20,000 ل.س'}).shortValue, '20,000 ل.س');
  });

  test('product reads store_coupons', () {
    final p = Product.fromJson({
      'id': 1, 'name': 'x', 'slug': 'x', 'price': 35000,
      'store_coupons': [
        {'id': 9, 'title': 't', 'type': 'fixed', 'value_label': 'خصم 5,000 ل.س', 'state': 'collectable'},
      ],
    });
    expect(p.storeCoupons.single.id, 9);
    expect(Product.fromJson({'id': 2, 'name': 'y', 'slug': 'y', 'price': 1}).storeCoupons, isEmpty);
  });

  test('order item marks gift', () {
    final gift = OrderItem.fromJson({'id': 1, 'product_name': 'كوب', 'unit_price': 0, 'quantity': 1, 'subtotal': 0, 'is_gift': true});
    expect(gift.isGift, isTrue);
    expect(gift.displayName, 'كوب (هدية)');
    expect(OrderItem.fromJson({'id': 2, 'product_name': 'x', 'unit_price': 5, 'quantity': 1, 'subtotal': 5}).displayName, 'x');
  });
}
