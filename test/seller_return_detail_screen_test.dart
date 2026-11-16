import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/return_request.dart';
import 'package:trendsham/screens/seller/seller_return_detail_screen.dart';
import 'package:trendsham/services/seller_return_service.dart';

ReturnRequest _request({
  bool approve = false,
  bool reject = false,
  bool received = false,
}) =>
    ReturnRequest.fromJson({
      'id': 31,
      'number': 'RT-31',
      'status': 'requested',
      'reason': 'damaged',
      'order_id': 5,
      'customer_name': 'سارة',
      'refund_amount': 200,
      'shipping_refund': 0,
      'actions': {
        'can_approve': approve,
        'can_reject': reject,
        'can_confirm_received': received,
      },
    });

class _FakeSellerReturnService extends SellerReturnService {
  _FakeSellerReturnService(this.request);

  final ReturnRequest request;
  int approveCalls = 0;
  int rejectCalls = 0;
  int receivedCalls = 0;
  String? lastRejectNote;

  @override
  Future<ReturnRequest> show(int id) async => request;

  @override
  Future<ReturnRequest> approve(int id, {String? note}) async {
    approveCalls++;
    throw const FormatException('bad body');
  }

  @override
  Future<ReturnRequest> reject(int id, {required String note}) async {
    rejectCalls++;
    lastRejectNote = note;
    throw const FormatException('bad body');
  }

  @override
  Future<ReturnRequest> confirmReceived(int id) async {
    receivedCalls++;
    throw const FormatException('bad body');
  }
}

Future<void> _pump(WidgetTester tester, SellerReturnService service) async {
  tester.view.physicalSize = const Size(420, 2200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SellerReturnDetailScreen(returnId: 31, service: service),
  ));
  await tester.pump();
  await tester.pump();
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets('buttons come only from server actions', (tester) async {
    await _pump(tester,
        _FakeSellerReturnService(_request(approve: true, reject: true)));
    expect(find.text('سارة'), findsOneWidget);
    expect(find.text('الموافقة على الإرجاع'), findsOneWidget);
    expect(find.text('رفض الإرجاع'), findsOneWidget);
    expect(find.text('تأكيد استلام المرتجع'), findsNothing);
    await _settle(tester);

    await _pump(tester, _FakeSellerReturnService(_request(received: true)));
    expect(find.text('تأكيد استلام المرتجع'), findsOneWidget);
    expect(find.text('الموافقة على الإرجاع'), findsNothing);
    expect(find.text('رفض الإرجاع'), findsNothing);
    await _settle(tester);

    await _pump(tester, _FakeSellerReturnService(_request()));
    expect(find.byType(FilledButton), findsNothing);
    expect(find.byType(OutlinedButton), findsNothing);
    await _settle(tester);
  });

  testWidgets('reject is blocked without a note', (tester) async {
    final fake =
        _FakeSellerReturnService(_request(approve: true, reject: true));
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('رفض الإرجاع'));
    await tester.tap(find.text('رفض الإرجاع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.tap(find.text('إرسال الرفض'));
    await tester.pump();

    expect(fake.rejectCalls, 0);
    expect(find.text('اكتب سبب الرفض.'), findsOneWidget);
    await _settle(tester);
  });

  testWidgets('reject recovers from an unexpected error', (tester) async {
    final fake =
        _FakeSellerReturnService(_request(approve: true, reject: true));
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('رفض الإرجاع'));
    await tester.tap(find.text('رفض الإرجاع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.enterText(find.byType(TextField), 'المنتج مستعمل');
    await tester.tap(find.text('إرسال الرفض'));
    await tester.pump();
    await tester.pump();

    expect(fake.rejectCalls, 1);
    expect(fake.lastRejectNote, 'المنتج مستعمل');
    expect(find.text('تعذّر رفض طلب الإرجاع.'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إرسال الرفض'));
    expect(submit.onPressed, isNotNull);
    await _settle(tester);
  });

  testWidgets('approve shows feedback on an unexpected error', (tester) async {
    final fake =
        _FakeSellerReturnService(_request(approve: true, reject: true));
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('الموافقة على الإرجاع'));
    await tester.tap(find.text('الموافقة على الإرجاع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('إرسال الموافقة'));
    await tester.pump();
    await tester.pump();

    expect(fake.approveCalls, 1);
    expect(find.text('تعذّر الموافقة على طلب الإرجاع.'), findsOneWidget);
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إرسال الموافقة'));
    expect(submit.onPressed, isNotNull);
    await _settle(tester);
  });

  testWidgets('confirm received asks first and recovers from errors',
      (tester) async {
    final fake = _FakeSellerReturnService(_request(received: true));
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('تأكيد استلام المرتجع'));
    await tester.tap(find.text('تأكيد استلام المرتجع'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(fake.receivedCalls, 0);

    await tester.tap(find.text('نعم، استلمت المرتجع'));
    await tester.pump();
    await tester.pump();

    expect(fake.receivedCalls, 1);
    expect(find.text('تعذّر تأكيد استلام المرتجع.'), findsOneWidget);
    final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'تأكيد استلام المرتجع'));
    expect(button.onPressed, isNotNull);
    await _settle(tester);
  });
}
