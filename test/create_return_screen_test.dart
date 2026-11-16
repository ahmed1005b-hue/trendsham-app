import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/return_request.dart';
import 'package:trendsham/screens/returns/create_return_screen.dart';
import 'package:trendsham/screens/returns/return_detail_screen.dart';
import 'package:trendsham/services/api_exception.dart';
import 'package:trendsham/services/return_service.dart';

const _line = ReturnableLine(
  orderItemId: 9,
  productName: 'قميص أزرق',
  unitPrice: 100,
  quantity: 3,
  returnableQuantity: 2,
);

ReturnRequest _created() => ReturnRequest.fromJson({
      'id': 77,
      'number': 'RT-77',
      'status': 'requested',
      'reason': 'damaged',
      'order_id': 5,
      'refund_amount': 200,
      'shipping_refund': 0,
    });

class _FakeReturnService extends ReturnService {
  _FakeReturnService({this.failWith});
  final ApiException? failWith;
  int calls = 0;
  Map<int, int>? lines;
  String? reason;
  String? description;

  @override
  Future<ReturnRequest> create(
    int orderId, {
    required Map<int, int> lines,
    required String reason,
    String? description,
    List<XFile> photos = const [],
  }) async {
    calls++;
    this.lines = lines;
    this.reason = reason;
    this.description = description;
    if (failWith != null) throw failWith!;
    return _created();
  }

  @override
  Future<ReturnRequest> show(int id) async => _created();
}

Future<void> _pump(WidgetTester tester, ReturnService service,
    {List<ReturnableLine> lines = const [_line]}) async {
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
    home: CreateReturnScreen(orderId: 5, lines: lines, service: service),
  ));
  await tester.pump();
}

Future<void> _submit(WidgetTester tester) async {
  await tester.ensureVisible(find.text('إرسال طلب الإرجاع'));
  await tester.tap(find.text('إرسال طلب الإرجاع'));
  await tester.pump();
}

void main() {
  testWidgets('requires a line with quantity before sending', (tester) async {
    final fake = _FakeReturnService();
    await _pump(tester, fake);

    await tester.tap(find.byKey(const ValueKey('reason-damaged')));
    await tester.pump();
    await _submit(tester);

    expect(find.text('اختر منتجاً واحداً على الأقل بكمية أكبر من صفر.'),
        findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('requires a reason before sending', (tester) async {
    final fake = _FakeReturnService();
    await _pump(tester, fake);

    await tester.tap(find.byTooltip('زيادة الكمية'));
    await tester.pump();
    await _submit(tester);

    expect(find.text('اختر سبب الإرجاع.'), findsOneWidget);
    expect(fake.calls, 0);
  });

  testWidgets('quantity stepper is capped at the returnable quantity',
      (tester) async {
    await _pump(tester, _FakeReturnService());

    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byTooltip('زيادة الكمية'));
      await tester.pump();
    }
    expect(tester.widget<Text>(find.byKey(const ValueKey('qty-9'))).data, '2');
  });

  testWidgets('valid form sends lines and reason, then opens the detail',
      (tester) async {
    final fake = _FakeReturnService();
    await _pump(tester, fake);

    await tester.tap(find.byTooltip('زيادة الكمية'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reason-damaged')));
    await tester.pump();
    await _submit(tester);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.calls, 1);
    expect(fake.lines, {9: 1});
    expect(fake.reason, 'damaged');
    expect(find.byType(ReturnDetailScreen), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('groups lines by store when the order has several stores',
      (tester) async {
    await _pump(tester, _FakeReturnService(), lines: const [
      ReturnableLine(
          orderItemId: 1,
          vendorId: 4,
          storeName: 'متجر أ',
          productName: 'قميص',
          unitPrice: 100,
          quantity: 1,
          returnableQuantity: 1),
      ReturnableLine(
          orderItemId: 2,
          vendorId: 5,
          storeName: 'متجر ب',
          productName: 'حذاء',
          unitPrice: 200,
          quantity: 1,
          returnableQuantity: 1),
      ReturnableLine(
          orderItemId: 3,
          vendorId: 4,
          storeName: 'متجر أ',
          productName: 'بنطال',
          unitPrice: 150,
          quantity: 1,
          returnableQuantity: 1),
    ]);

    expect(find.text('المتجر: متجر أ'), findsOneWidget);
    expect(find.text('المتجر: متجر ب'), findsOneWidget);
    expect(find.text('طلب الإرجاع الواحد يخص متجراً واحداً.'), findsOneWidget);
    // سطرا المتجر أ معاً قبل المتجر ب
    final shirt = tester.getTopLeft(find.text('قميص')).dy;
    final trousers = tester.getTopLeft(find.text('بنطال')).dy;
    final storeB = tester.getTopLeft(find.text('المتجر: متجر ب')).dy;
    expect(shirt < trousers && trousers < storeB, isTrue);
  });

  test('reason labels match the server REASON_LABELS', () {
    expect(returnReasonLabel('damaged'), 'المنتج تالف');
    expect(returnReasonLabel('not_as_described'), 'لا يطابق الوصف');
    expect(returnReasonLabel('wrong_size_or_color'), 'مقاس أو لون خاطئ');
    expect(returnReasonLabel('changed_mind'), 'غيّرت رأيي');
    expect(returnReasonLabel('other'), 'سبب آخر');
  });

  testWidgets('shows the server business error and stays on the form',
      (tester) async {
    final fake = _FakeReturnService(
        failWith: const ApiException('انتهت مهلة الإرجاع.', statusCode: 422));
    await _pump(tester, fake);

    await tester.tap(find.byTooltip('زيادة الكمية'));
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('reason-damaged')));
    await tester.pump();
    await _submit(tester);
    await tester.pump();

    expect(find.text('انتهت مهلة الإرجاع.'), findsOneWidget);
    expect(find.byType(ReturnDetailScreen), findsNothing);
  });
}
