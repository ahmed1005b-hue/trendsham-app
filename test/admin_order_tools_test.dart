import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/order.dart';
import 'package:trendsham/screens/admin/admin_order_detail_screen.dart';
import 'package:trendsham/screens/admin/admin_orders_screen.dart';
import 'package:trendsham/services/admin_operations_service.dart';
import 'package:trendsham/services/admin_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';

Order _order({
  String status = 'shipped',
  List<Shipment>? shipments,
  List<OrderTimelineEvent> timeline = const [],
  String? archiveBlocker,
}) =>
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
      paymentStatus: 'unpaid',
      paymentMethod: 'cash_on_delivery',
      shipments: shipments ??
          [Shipment(id: 3, status: 'shipped', sellerName: 'متجر الورد')],
      timeline: timeline,
      archiveBlocker: archiveBlocker,
    );

class _FakeAdminService extends AdminService {
  _FakeAdminService(this.order);

  Order order;
  final calls = <String>[];

  @override
  Future<List<Order>> orders(
      {bool employeeMode = false,
      String? query,
      String? view,
      String? status}) async {
    calls.add('list:${query ?? ''}:${view ?? ''}:${status ?? ''}');
    return [order];
  }

  @override
  Future<Order> getOrder(int id, {bool employeeMode = false}) async => order;

  @override
  Future<({Order order, String? message})> markRefused(
      int orderId, int shipmentId,
      {bool employeeMode = false}) async {
    calls.add('refused:$shipmentId:$employeeMode');
    order = _order(
        status: 'cancelled',
        shipments: [Shipment(id: 3, status: 'cancelled', refused: true)],
        timeline: order.timeline,
        archiveBlocker: order.archiveBlocker);
    return (order: order, message: 'سُجّل');
  }
}

class _FakeOperations extends AdminOperationsService {
  final calls = <String>[];

  @override
  Future<List<Map<String, dynamic>>> shippingCompanies(
          {bool employeeMode = false}) async =>
      const [];

  @override
  Future<Order> updateShipment(int orderId, int shipmentId,
      {required String status,
      int? shippingCompanyId,
      String? trackingNumber,
      String? reason,
      bool employeeMode = false}) async {
    calls.add('parcel:$status:${reason ?? ''}:$employeeMode');
    return _order(status: status);
  }
}

Future<void> _pump(WidgetTester tester, Widget home) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(ChangeNotifierProvider(
    create: (_) => ThemeController(prefs: prefs),
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: home,
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('the order list searches and switches views', (tester) async {
    final service = _FakeAdminService(_order());
    await _pump(
        tester,
        AdminOrdersScreen(
            employeeMode: true, service: service, initialView: 'late'));
    await tester.pumpAndSettle();

    expect(service.calls, ['list::late:']);
    // الموظف لا يرى الأرشيف
    expect(find.byKey(const ValueKey('orders-view-archived')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('orders-search')), '0933');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('orders-view-new')));
    await tester.pumpAndSettle();

    expect(service.calls, ['list::late:', 'list:0933:late:', 'list:0933:new:']);
  });

  testWidgets('the admin sees the archive view', (tester) async {
    await _pump(
        tester, AdminOrdersScreen(service: _FakeAdminService(_order())));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('orders-view-archived')), findsOneWidget);
  });

  testWidgets(
      'the employee records a refused parcel and sees the timeline and archive rule',
      (tester) async {
    final service = _FakeAdminService(_order(
      timeline: [
        OrderTimelineEvent(
            kind: 'created',
            text: 'أنشأ الزبون الطلب',
            at: DateTime(2026, 11, 20, 10)),
        const OrderTimelineEvent(
            kind: 'staff', text: 'غيّر حالة الطلب', by: 'ليلى (موظف)'),
      ],
      archiveBlocker:
          'لا يُؤرشف إلا طلب ملغى، أو طلب مُسلَّم انتهت مدة إرجاعه.',
    ));
    await _pump(
        tester,
        AdminOrderDetailScreen(
            orderId: 7,
            employeeMode: true,
            service: service,
            operations: _FakeOperations()));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('parcel-refused-3')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('parcel-refused-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-refused-confirm')));
    await tester.pumpAndSettle();

    expect(service.calls, ['refused:3:true']);
    expect(find.byKey(const ValueKey('parcel-refused-3')), findsNothing);

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('order-timeline')), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('أنشأ الزبون الطلب'), findsOneWidget);
    expect(find.text('ليلى (موظف)'), findsOneWidget);
    await tester.scrollUntilVisible(find.textContaining('لا يُؤرشف إلا'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('أرشفة مع الاحتفاظ بالسجل'), findsNothing);
  });

  testWidgets('a shipped parcel cannot be cancelled from the parcel tools',
      (tester) async {
    final operations = _FakeOperations();
    await _pump(
        tester,
        AdminOrderDetailScreen(
            orderId: 7,
            employeeMode: true,
            service: _FakeAdminService(_order()),
            operations: operations));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('parcel-edit-3')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byKey(const ValueKey('parcel-edit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-status')));
    await tester.pumpAndSettle();

    final choices = tester
        .widgetList<DropdownMenuItem<String>>(
            find.byType(DropdownMenuItem<String>))
        .map((item) => item.value)
        .toSet();
    expect(choices, isNot(contains('cancelled')));
    expect(choices, contains('delivered'));

    await tester.tap(find.text('تم التسليم').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-save')));
    await tester.pumpAndSettle();

    expect(operations.calls, ['parcel:delivered::true']);
  });

  testWidgets('cancelling a pending parcel asks for a reason', (tester) async {
    final operations = _FakeOperations();
    await _pump(
        tester,
        AdminOrderDetailScreen(
            orderId: 7,
            service: _FakeAdminService(_order(status: 'pending', shipments: [
              Shipment(id: 3, status: 'pending', sellerName: 'متجر الورد'),
              Shipment(id: 4, status: 'pending', sellerName: 'متجر الأحذية'),
            ])),
            operations: operations));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('parcel-edit-3')), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.ensureVisible(find.byKey(const ValueKey('parcel-edit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-edit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملغي').last);
    await tester.pumpAndSettle();

    // بلا سبب: لا يُرسل
    await tester.tap(find.byKey(const ValueKey('parcel-save')));
    await tester.pumpAndSettle();
    expect(operations.calls, isEmpty);
    await tester.pump(const Duration(seconds: 5)); // تختفي رسالة «اكتب السبب»
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.byKey(const ValueKey('parcel-edit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-edit-3')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('parcel-status')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملغي').last);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const ValueKey('parcel-cancel-reason')), 'نفدت الكمية');
    await tester.tap(find.byKey(const ValueKey('parcel-save')));
    await tester.pumpAndSettle();

    expect(operations.calls, ['parcel:cancelled:نفدت الكمية:false']);
  });
}
