import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/widgets/order_tracker_timeline.dart';

void main() {
  test('parses tracking data from the nested shipment resource', () {
    final order = Order.fromJson({
      'id': 42,
      'order_number': 'TS-42',
      'status': 'shipped',
      'subtotal': 100,
      'shipping_fee': 10,
      'discount_amount': 0,
      'total': 110,
      'shipping_name': 'Customer',
      'shipping_phone': '0999999999',
      'shipping_address': 'Damascus',
      'can_be_cancelled': false,
      'shipment': {
        'status': 'shipped',
        'tracking_number': 'TRACK-123',
        'shipping_company': 'Fast Delivery',
      },
    });

    expect(order.shipmentStatus, 'shipped');
    expect(order.trackingNumber, 'TRACK-123');
    expect(order.shippingCompany, 'Fast Delivery');
  });

  testWidgets('shows shipment tracking details after dispatch', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        locale: Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: OrderTrackerTimeline(
            status: 'shipped',
            trackingNumber: 'TRACK-123',
            shippingCompany: 'Fast Delivery',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRACK-123'), findsOneWidget);
    expect(find.textContaining('Fast Delivery'), findsOneWidget);
    expect(find.textContaining('تتبع'), findsOneWidget);
  });
}
