import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/seller_coupon.dart';
import 'package:trendsham/screens/seller/seller_coupons_screen.dart';
import 'package:trendsham/services/seller_coupon_service.dart';

SellerCoupon _coupon({
  int id = 1,
  String status = 'active',
  bool locked = false,
}) =>
    SellerCoupon.fromJson({
      'id': id,
      'title': 'خصم الافتتاح',
      'type': 'percentage',
      'value': 10,
      'value_label': 'خصم 10%',
      'max_discount': 20000,
      'scope': 'all',
      'audience': 'collectable',
      'ends_at': '2026-12-31T00:00:00Z',
      'total_limit': 100,
      'issued_count': locked ? 3 : 0,
      'status': status,
      'status_label': status,
      'is_locked': locked,
    });

class _FakeService extends SellerCouponService {
  _FakeService(this.page);

  SellerCouponsPage page;
  Map<String, dynamic>? createdBody;
  final toggled = <int>[];

  @override
  Future<SellerCouponsPage> list() async => page;

  @override
  Future<String> create(Map<String, dynamic> body) async {
    createdBody = body;
    return 'تم';
  }

  @override
  Future<SellerCoupon> toggle(int id) async {
    toggled.add(id);
    return _coupon(id: id, status: 'paused');
  }
}

Widget _app(SellerCouponService service) => MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SellerCouponsScreen(service: service),
    );

void main() {
  setUp(() {});

  testWidgets(
      'lists coupons; pending one cannot be toggled, collected one cannot be deleted',
      (tester) async {
    final service = _FakeService(SellerCouponsPage(coupons: [
      _coupon(id: 1),
      _coupon(id: 2, status: 'pending_review'),
      _coupon(id: 3, locked: true),
    ]));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coupon-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('toggle-2')), findsNothing);
    expect(find.byKey(const ValueKey('delete-1')), findsOneWidget);
    expect(find.byKey(const ValueKey('delete-3')), findsNothing);
    expect(find.byKey(const ValueKey('new-coupon')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('toggle-1')));
    await tester.pumpAndSettle();
    expect(service.toggled, [1]);
  });

  testWidgets('unverified store sees the reason and no add button',
      (tester) async {
    final service = _FakeService(const SellerCouponsPage(
      coupons: [],
      blockReason: 'وثّق متجرك أولاً',
    ));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('coupon-blocked')), findsOneWidget);
    expect(find.byKey(const ValueKey('new-coupon')), findsNothing);
  });

  testWidgets('new coupon form sends the web panel fields', (tester) async {
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final service = _FakeService(const SellerCouponsPage(coupons: []));
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('new-coupon')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('coupon-title')), 'خصم الصيف');
    await tester.enterText(find.byKey(const ValueKey('coupon-value')), '15');
    await tester.enterText(find.byKey(const ValueKey('coupon-max')), '5000');
    await tester.tap(find.byKey(const ValueKey('coupon-save')));
    await tester.pumpAndSettle();

    final body = service.createdBody!;
    expect(body['title'], 'خصم الصيف');
    expect(body['type'], 'percentage');
    expect(body['value'], 15);
    expect(body['max_discount'], 5000);
    expect(body['scope'], 'all');
    expect(body['audience'], 'collectable');
    expect(body['total_limit'], 100);
    expect(body['per_customer_limit'], 1);
    expect(body['ends_at'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}$')));
    // رجعنا للقائمة بعد الحفظ
    expect(find.byKey(const ValueKey('coupon-save')), findsNothing);
  });
}
