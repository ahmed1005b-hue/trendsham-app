import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/order.dart';

/// طرد لكل متجر: قراءة الطرود من الخادم وحساب «شُحن جزئياً».
void main() {
  Map<String, dynamic> orderJson(List<Map<String, dynamic>> shipments) => {
        'id': 1,
        'order_number': 'TS-1',
        'status': 'shipped',
        'subtotal': 200,
        'shipping_fee': 20,
        'discount_amount': 0,
        'total': 220,
        'shipping_name': 'Sam',
        'shipping_phone': '0999',
        'shipping_address': 'Aleppo',
        'can_be_cancelled': false,
        'items': [
          {'id': 1, 'product_name': 'قميص', 'vendor_id': 5, 'unit_price': 100, 'quantity': 1, 'subtotal': 100},
          {'id': 2, 'product_name': 'حذاء', 'vendor_id': 6, 'unit_price': 100, 'quantity': 1, 'subtotal': 100},
        ],
        'shipments': shipments,
      };

  test('one shipped and one pending parcel is partly shipped', () {
    final order = Order.fromJson(orderJson([
      {'id': 10, 'seller_profile_id': 5, 'status': 'shipped', 'tracking_number': 'KR-1'},
      {'id': 11, 'seller_profile_id': 6, 'status': 'pending', 'can_be_cancelled': true},
    ]));

    expect(order.isPartiallyShipped, isTrue);
    expect(order.shipments[1].canBeCancelled, isTrue);
    expect(order.items.first.vendorId, 5);
    expect(order.shipments[0].statusLabel, 'تم الشحن');
  });

  test('a cancelled parcel does not make the order partly shipped', () {
    final order = Order.fromJson(orderJson([
      {'id': 10, 'seller_profile_id': 5, 'status': 'shipped'},
      {'id': 11, 'seller_profile_id': 6, 'status': 'cancelled', 'refund_amount': 110},
    ]));

    expect(order.isPartiallyShipped, isFalse);
    expect(order.shipments[1].isOpen, isFalse);
    expect(order.shipments[1].refundAmount, 110);
  });
}
