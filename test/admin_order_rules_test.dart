import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/screens/admin/admin_order_detail_screen.dart';
import 'package:trendsham/services/admin_service.dart';

Order _order(
        {String status = 'pending',
        bool paid = false,
        List<Shipment> shipments = const []}) =>
    Order(
      id: 7,
      orderNumber: 'TS-7',
      status: status,
      subtotal: 200,
      shippingFee: 0,
      discountAmount: 0,
      total: 200,
      shippingName: 'زبون',
      shippingPhone: '0999',
      shippingAddress: 'دمشق',
      canBeCancelled: false,
      needsRefundBeforeCancel: paid,
      paymentStatus: paid ? 'paid' : 'unpaid',
      paymentMethod: paid ? 'card' : 'cash_on_delivery',
      shipments: shipments,
    );

class _FakeAdminService extends AdminService {
  _FakeAdminService(this.order);

  Order order;
  final calls = <String>[];

  @override
  Future<Order> getOrder(int id, {bool employeeMode = false}) async => order;

  @override
  Future<Order> updateOrderStatus(int id, String status,
      {String? trackingNumber,
      String? reason,
      bool employeeMode = false}) async {
    calls.add('status:$status:${reason ?? ''}');
    return order = _order(status: status);
  }

  @override
  Future<Order> cancelWithRefund(int id,
      {required String reason, required String method, String? note}) async {
    calls.add('refund:$method:$reason');
    return order = _order(status: 'cancelled');
  }
}

void main() {
  Future<void> pump(WidgetTester tester, AdminService service,
      {bool employeeMode = false}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminOrderDetailScreen(
          orderId: 7, employeeMode: employeeMode, service: service),
    ));
    await tester.pumpAndSettle();
  }

  Future<List<String>> statusChoices(WidgetTester tester) async {
    await tester.tap(find.byKey(const ValueKey('order-status-pending')));
    await tester.pumpAndSettle();
    final choices = tester
        .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>))
        .map((item) => item.value!)
        .toSet()
        .toList();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();
    return choices;
  }

  testWidgets('cancelling asks for a reason and sends it', (tester) async {
    final service = _FakeAdminService(_order());
    await pump(tester, service, employeeMode: true);

    expect(await statusChoices(tester),
        ['processing', 'shipped', 'delivered', 'cancelled']);

    await tester.tap(find.byKey(const ValueKey('order-status-pending')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملغي').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('order-status-save')));
    await tester.pumpAndSettle();

    await tester.enterText(
        find.byKey(const ValueKey('order-cancel-reason')), 'نفدت الكمية');
    await tester.tap(find.byKey(const ValueKey('order-cancel-confirm')));
    await tester.pumpAndSettle();

    expect(service.calls, ['status:cancelled:نفدت الكمية']);
    expect(find.text('الطلب ملغى.'), findsOneWidget);
  });

  testWidgets('a paid order is cancelled only with the refund recorded',
      (tester) async {
    final service = _FakeAdminService(_order(paid: true));
    await pump(tester, service);

    expect(await statusChoices(tester), isNot(contains('cancelled')));

    await tester
        .ensureVisible(find.byKey(const ValueKey('order-cancel-refund')));
    await tester.tap(find.byKey(const ValueKey('order-cancel-refund')));
    await tester.pumpAndSettle();

    // بلا طريقة رد: لا يُرسل شيء
    await tester.tap(find.byKey(const ValueKey('refund-submit')));
    await tester.pumpAndSettle();
    expect(service.calls, isEmpty);

    await tester.tap(find.byKey(const ValueKey('refund-method')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('تحويل بنكي').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('refund-reason')), 'طلب الزبون');
    await tester.tap(find.byKey(const ValueKey('refund-submit')));
    await tester.pumpAndSettle();

    expect(service.calls, ['refund:bank_transfer:طلب الزبون']);
  });

  testWidgets('an employee sees no refund button on a paid order',
      (tester) async {
    await pump(tester, _FakeAdminService(_order(paid: true)),
        employeeMode: true);

    expect(find.byKey(const ValueKey('order-cancel-refund')), findsNothing);
    expect(find.textContaining('يلغيه المدير'), findsOneWidget);
  });

  test('a shipped order cannot be cancelled', () {
    final order = _order(status: 'processing', shipments: [
      Shipment(id: 1, status: 'shipped'),
    ]);
    expect(order.hasShipped, isTrue);
  });
}
