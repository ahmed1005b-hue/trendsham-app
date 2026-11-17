import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/seller_profile.dart';
import 'package:trendsham/models/vendor.dart';
import 'package:trendsham/screens/seller/seller_store_profile_screen.dart';
import 'package:trendsham/services/api_client.dart';
import 'package:trendsham/services/shipping_center_service.dart';
import 'package:trendsham/services/store_service.dart';
import 'package:trendsham/services/store_visitor_token_storage.dart';
import 'package:trendsham/widgets/attribution_metrics_card.dart';

class _FakeApiClient extends ApiClient {
  Map<String, dynamic>? query;

  @override
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool withAuth = true,
    Map<String, String>? headers,
  }) async {
    this.query = query;
    return {
      'store': {'id': 8, 'store_name': 'متجر'},
      'featured': {},
      'products': {
        'data': [],
        'meta': {
          'current_page': 1,
          'last_page': 3,
          'per_page': 20,
          'total': 54,
        },
      },
    };
  }
}

class _FakeVisitorTokens extends StoreVisitorTokenStorage {
  @override
  Future<String> getOrCreate() async => 'a' * 64;

  @override
  Future<void> save(String token) async {}
}

void main() {
  test('store models parse contact, hours, and policy fields', () {
    final vendor = Vendor.fromJson({
      'id': 12,
      'store_name': 'متجر',
      'store_contact_phone': '+963999123456',
      'store_whatsapp': 'https://wa.me/963999123456',
      'store_instagram': 'https://instagram.com/store',
      'business_hours': 'يومياً',
      'shipping_policy': 'الشحن خلال يومين.',
      'return_policy': 'الإرجاع خلال أسبوع.',
      'is_followed': true,
      'followers_count': 11,
      'business_hours_status': {
        'state': 'open',
        'label': 'مفتوح الآن',
        'next_change_at': '2026-11-02T13:00:00+03:00',
      },
    });
    final seller = SellerProfileModel.fromJson({
      'id': 12,
      'store_name': 'متجر',
      'store_contact_phone': '+963999123456',
      'business_hours': 'يومياً',
      'shipping_policy': 'الشحن خلال يومين.',
      'return_policy': 'الإرجاع خلال أسبوع.',
      'status': 'approved',
      'commission_rate': 10,
      'business_hours_schedule': {
        'timezone': 'Asia/Damascus',
        'days': {'mon': []},
      },
    });

    expect(vendor.storeContactPhone, '+963999123456');
    expect(vendor.storeWhatsapp, 'https://wa.me/963999123456');
    expect(vendor.businessHours, 'يومياً');
    expect(vendor.shippingPolicy, 'الشحن خلال يومين.');
    expect(vendor.returnPolicy, 'الإرجاع خلال أسبوع.');
    expect(vendor.isFollowed, isTrue);
    expect(vendor.followersCount, 11);
    expect(vendor.businessHoursStatus?['state'], 'open');
    expect(seller.storeContactPhone, '+963999123456');
    expect(seller.returnPolicy, 'الإرجاع خلال أسبوع.');
    expect(seller.businessHoursSchedule?['timezone'], 'Asia/Damascus');
  });

  test('public store page keeps featured merchandise separate from pagination',
      () {
    final featured = Product(
      id: 21,
      slug: 'featured',
      name: 'الأكثر مبيعاً',
      price: 20,
      stockQuantity: 3,
      inStock: true,
      reviewsCount: 0,
    );
    final recent = Product(
      id: 22,
      slug: 'recent',
      name: 'وصل حديثاً',
      price: 25,
      stockQuantity: 2,
      inStock: true,
      reviewsCount: 0,
    );
    final page = StorePage(
      store: Vendor.fromJson({'id': 1, 'store_name': 'متجر'}),
      products: [featured, recent],
      bestSelling: [featured],
      recentArrivals: [recent],
      currentPage: 1,
      lastPage: 4,
      total: 72,
    );

    expect(page.products, hasLength(2));
    expect(page.bestSelling.single.id, 21);
    expect(page.recentArrivals.single.id, 22);
    expect(page.total, 72);
  });

  test('store filters are sent to the server with pagination parameters',
      () async {
    final api = _FakeApiClient();
    final service = StoreService(
      api: api,
      visitorTokens: _FakeVisitorTokens(),
    );

    final page = await service.show(
      8,
      page: 2,
      priceMin: 10.5,
      priceMax: 90,
      ratingMin: 4.5,
      inStock: true,
    );

    expect(api.query?['page'], 2);
    expect(api.query?['price_min'], 10.5);
    expect(api.query?['price_max'], 90);
    expect(api.query?['rating_min'], 4.5);
    expect(api.query?['in_stock'], 1);
    expect(page.currentPage, 1);
    expect(page.total, 54);
  });

  testWidgets('attribution metrics explain the measured conversion rate',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: AttributionMetricsCard(
            totalVisits: 10,
            convertingVisits: 2,
            attributedOrders: 3,
            conversionRate: 20,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('2 من 10 زيارة'), findsOneWidget);
    expect(find.textContaining('20.00%'), findsOneWidget);
    expect(find.textContaining('الطلبات غير المرتبطة'), findsOneWidget);
  });

  testWidgets('seller storefront preview updates before saving',
      (tester) async {
    final store = SellerProfileModel(
      id: 1,
      storeName: 'اسم سابق',
      status: 'approved',
      commissionRate: 10,
    );
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: SellerStoreProfileScreen(
            store: store,
            centerService: ShippingCenterService(api: _FakeApiClient())),
      ),
    );
    await tester.pumpAndSettle();

    final nameField = find.byKey(const ValueKey('store-name-input'));
    await tester.scrollUntilVisible(
      nameField,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(nameField, 'اسم جديد للمعاينة');
    await tester.pump();

    await tester.scrollUntilVisible(
      find.textContaining('معاينة مباشرة'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    expect(find.text('اسم جديد للمعاينة'), findsWidgets);
    expect(find.textContaining('معاينة مباشرة'), findsOneWidget);
  });
}
