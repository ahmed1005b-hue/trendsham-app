import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/checkout_service.dart';

/// شحن مستقل لكل متجر: ملخص الدفع يحمل طرد كل متجر بطريقته وأجرته ومدة وصوله.
void main() {
  test('summary reads each store parcel, the governorate and the list', () {
    final s = CheckoutSummary.fromJson({
      'subtotal': 200,
      'shipping_fee': 20000,
      'discount': 0,
      'total': 20200,
      'shipping_governorate': 'دمشق',
      'governorates': ['دمشق', 'حلب'],
      'parcels': [
        {
          'vendor_id': 7,
          'store_name': 'Store a',
          'fee': 5000,
          'heavy': false,
          'mode': 'self',
          'mode_label': 'توصيل من المتجر نفسه',
          'eta_label': 'يصل خلال 2 إلى 3 أيام',
          'can_pickup': true,
          'pickup_address': 'دمشق - الحمرا',
        },
        {
          'vendor_id': 9,
          'store_name': 'Store b',
          'fee': 15000,
          'heavy': true,
          'mode': 'platform'
        },
      ],
    });

    expect(s.shippingGovernorate, 'دمشق');
    expect(s.governorates, ['دمشق', 'حلب']);
    expect(s.parcelCount, 2);
    expect(s.hasHeavyParcel, isTrue);
    expect(s.parcels.first.vendorId, 7);
    expect(s.parcels.first.mode, 'self');
    expect(s.parcels.first.fee, 5000);
    expect(s.parcels.first.canPickup, isTrue);
    expect(s.parcels.first.pickupAddress, 'دمشق - الحمرا');
    expect(s.parcels.last.mode, 'platform');
    expect(s.parcels.last.canPickup, isFalse);
  });

  test('an older server without the new fields still parses', () {
    final s = CheckoutSummary.fromJson(
        {'subtotal': 1, 'shipping_fee': 1, 'total': 2});
    expect(s.parcels, isEmpty);
    expect(s.governorates, isEmpty);
    expect(s.shippingGovernorate, isNull);
  });
}
