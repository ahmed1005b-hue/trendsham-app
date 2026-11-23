import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/screens/seller/parcel_actions.dart';

void main() {
  test('صف طلب البائع يحمل رقم الطلب والحالات المسموحة', () {
    final item = OrderItem.fromJson({
      'id': 55, // رقم المنتج داخل الطلب
      'order_id': 9, // رقم الطلب الذي يُحدَّث
      'product_name': 'قميص',
      'order_number': 'TS-1',
      'order_status': 'pending',
      'unit_price': 100,
      'quantity': 1,
      'subtotal': 100,
      'can_be_reviewed': false,
      'next_statuses': ['processing', 'cancelled'],
    });

    expect(item.orderId, 9);
    expect(item.nextStatuses, ['processing', 'cancelled']);
  });

  test('صف قديم بلا order_id أو next_statuses لا ينكسر', () {
    final item =
        OrderItem.fromJson({'id': 3, 'product_name': 'x', 'quantity': 1});

    expect(item.orderId, isNull);
    expect(item.nextStatuses, isNull);
  });
  test('ملصق الشحنة يظهر للطرود المفتوحة فقط', () {
    OrderItem row(String? parcel, {int? orderId = 9}) => OrderItem.fromJson({
          'id': 1,
          'order_id': orderId,
          'product_name': 'x',
          'quantity': 1,
          'parcel_status': parcel,
        });

    expect(canPrintParcelLabel(row('processing')), isTrue);
    expect(canPrintParcelLabel(row(null)), isTrue);
    expect(canPrintParcelLabel(row('cancelled')), isFalse);
    expect(canPrintParcelLabel(row('returned')), isFalse);
    expect(canPrintParcelLabel(row('pending', orderId: null)), isFalse);
  });
}
