import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/models/seller_parcel.dart';
import 'package:trendsham/screens/seller/seller_order_detail_screen.dart';
import 'package:trendsham/services/seller_service.dart';

/// تفاصيل الطلب للبائع في التطبيق: نفس صفحة الطلب في الموقع.
class _FakeSellerService extends SellerService {
  _FakeSellerService(this.parcel, {this.paid = false});

  final Map<String, dynamic> parcel;
  final bool paid;

  @override
  Future<(Order, SellerParcel)> orderDetail(int orderId) async => (
        Order.fromJson({
          'id': orderId,
          'order_number': 'TS-ABC123',
          'status': 'pending',
          'payment_status': paid ? 'paid' : 'unpaid',
          'subtotal': 125,
          'shipping_fee': 0,
          'discount_amount': 0,
          'total': 125,
          'shipping_name': 'سارة أحمد',
          'shipping_phone': '0999888777',
          'shipping_address': 'شارع بغداد، بناء 12',
          'items': [
            {
              'id': 1,
              'product_name': 'قميص قطن',
              'unit_price': 125,
              'quantity': 2,
              'subtotal': 250,
            },
          ],
        }),
        SellerParcel.fromJson(parcel),
      );
}

Future<void> _open(WidgetTester tester, SellerService service) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SellerOrderDetailScreen(orderId: 9, service: service),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a self-delivered cash parcel shows the amount to collect',
      (tester) async {
    await _open(
        tester,
        _FakeSellerService({
          'status': 'pending',
          'status_label': 'قيد المراجعة',
          'delivery_mode': 'self',
          'delivery_mode_label': 'توصيل من المتجر نفسه',
          'seller_delivers': true,
          'cod_amount': 12500,
          'shipping_governorate': 'دمشق',
          'is_shared': true,
          'next_statuses': ['processing', 'cancelled'],
          'can_print_label': true,
        }));

    expect(find.text('سارة أحمد'), findsOneWidget);
    expect(find.text('0999888777'), findsOneWidget);
    expect(find.text('دمشق'), findsOneWidget);
    expect(find.text('شارع بغداد، بناء 12'), findsOneWidget);
    expect(find.byKey(const ValueKey('parcel-cod')), findsOneWidget);
    expect(find.textContaining('12,500'), findsOneWidget);
    expect(find.text('قميص قطن'), findsOneWidget);
    expect(find.byKey(const ValueKey('detail-parcel-label')), findsOneWidget);
    expect(
        find.byKey(const ValueKey('detail-status-processing')), findsOneWidget);
  });

  testWidgets('a prepaid parcel says collect nothing; pickup hides the address',
      (tester) async {
    await _open(
        tester,
        _FakeSellerService({
          'status': 'processing',
          'delivery_mode': 'pickup',
          'seller_delivers': true,
          'cod_amount': 0,
          'next_statuses': <String>[],
          'can_print_label': true,
        }, paid: true));

    expect(find.byKey(const ValueKey('parcel-cod')), findsNothing);
    expect(find.textContaining('مدفوع مسبقاً'), findsOneWidget);
    expect(find.text('يستلمه الزبون من المحل'), findsOneWidget);
    expect(find.text('شارع بغداد، بناء 12'), findsNothing);
  });

  testWidgets('a cancelled parcel has no label button', (tester) async {
    await _open(
        tester,
        _FakeSellerService({
          'status': 'cancelled',
          'delivery_mode': 'platform',
          'next_statuses': <String>[],
          'can_print_label': false,
        }));

    expect(find.byKey(const ValueKey('detail-parcel-label')), findsNothing);
  });
}
