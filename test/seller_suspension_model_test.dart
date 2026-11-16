import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/seller_profile.dart';

void main() {
  test('المتجر الموقوف يحمل سبب الإيقاف', () {
    final s = SellerProfileModel.fromJson({
      'id': 4,
      'store_name': 'متجر',
      'status': 'suspended',
      'suspension_reason': 'شكاوى متكررة',
    });

    expect(s.isSuspended, isTrue);
    expect(s.suspensionReason, 'شكاوى متكررة');
  });

  test('المتجر المعتمد ليس موقوفاً', () {
    final s = SellerProfileModel.fromJson(
        {'id': 1, 'store_name': 'x', 'status': 'approved'});

    expect(s.isSuspended, isFalse);
    expect(s.suspensionReason, isNull);
  });
}
