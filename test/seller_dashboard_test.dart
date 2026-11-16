import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/seller_profile.dart';

void main() {
  group('Seller Dashboard Parsing & Statistics Tests', () {
    test('parses seller profile model correctly', () {
      final json = {
        'id': 5,
        'user_id': 10,
        'store_name': 'متجر الشام',
        'store_logo': 'https://example.com/store-logo.jpg',
        'store_banner': 'https://example.com/store-banner.jpg',
        'store_phone': '0912345678',
        'commission_rate': 7,
        'status': 'approved',
        'has_identity_document': true,
        'identity_document_submitted_at': '2026-10-25T12:30:00Z',
      };

      final profile = SellerProfileModel.fromJson(json);

      expect(profile.id, 5);
      expect(profile.storeName, 'متجر الشام');
      expect(profile.storeLogo, 'https://example.com/store-logo.jpg');
      expect(profile.storeBanner, 'https://example.com/store-banner.jpg');
      expect(profile.commissionRate, 7);
      expect(profile.status, 'approved');
      expect(profile.statusLabel, 'معتمد');
      expect(profile.hasIdentityDocument, isTrue);
      expect(profile.identityDocumentSubmittedAt, isNotNull);
    });

    test('legacy seller payload defaults to no identity document', () {
      final profile = SellerProfileModel.fromJson({
        'id': 6,
        'store_name': 'بائع سابق',
        'status': 'pending',
      });

      expect(profile.hasIdentityDocument, isFalse);
      expect(profile.identityDocumentSubmittedAt, isNull);
    });

    test('parses product views_count and sales_count from payload', () {
      final json = {
        'id': 101,
        'slug': 'p-101',
        'name': 'قميص رجالي',
        'price': '15000',
        'stock_quantity': 20,
        'in_stock': true,
        'reviews_count': 3,
        'views_count': 142,
        'sales_count': 28,
      };

      final product = Product.fromJson(json);

      expect(product.id, 101);
      expect(product.name, 'قميص رجالي');
      expect(product.viewsCount, 142);
      expect(product.salesCount, 28);
    });
  });
}
