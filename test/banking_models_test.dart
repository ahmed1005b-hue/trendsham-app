import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/services/payment_api.dart';

void main() {
  test('SavedCard يقرأ آخر 4 أرقام فقط ولا يحتاج رقم البطاقة', () {
    final card = SavedCard.fromJson({
      'id': 7,
      'brand': 'visa',
      'brand_label': 'Visa',
      'last4': '4242',
      'expiry': '09/29',
      'is_default': true,
    });
    expect(card.masked, '•••• 4242');
    expect(card.isDefault, isTrue);
    expect(card.isExpired, isFalse);
  });

  test('PaymentStartResult يفهم الدفع الفوري ببطاقة محفوظة', () {
    final r = PaymentStartResult.fromJson(
        {'reference': 'x', 'type': 'paid', 'paid': true});
    expect(r.paid, isTrue);
    expect(r.type, 'paid');
  });

  Map<String, dynamic> orderJson(String method, String paymentStatus) => {
        'id': 1,
        'order_number': 'TS-1',
        'status': 'pending',
        'subtotal': 100,
        'shipping_fee': 0,
        'discount_amount': 0,
        'total': 100,
        'shipping_name': 'a',
        'shipping_phone': '1',
        'shipping_address': 'b',
        'payment_status': paymentStatus,
        'payment_method': method,
      };

  test('زر الدفع يظهر فقط لطلبات البطاقة غير المدفوعة', () {
    expect(Order.fromJson(orderJson('card', 'unpaid')).awaitsOnlinePayment,
        isTrue);
    expect(Order.fromJson(orderJson('card', 'paid')).awaitsOnlinePayment,
        isFalse);
    expect(
        Order.fromJson(orderJson('cash_on_delivery', 'unpaid'))
            .awaitsOnlinePayment,
        isFalse);
  });
}
