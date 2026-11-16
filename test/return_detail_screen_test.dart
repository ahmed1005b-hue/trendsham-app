import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/return_request.dart';
import 'package:trendsham/screens/returns/return_detail_screen.dart';
import 'package:trendsham/services/return_service.dart';

ReturnRequest _rejected() => ReturnRequest.fromJson({
      'id': 77,
      'number': 'RT-77',
      'status': 'rejected',
      'reason': 'damaged',
      'order_id': 5,
      'refund_amount': 200,
      'shipping_refund': 0,
      'actions': {'can_withdraw': true, 'can_dispute': true},
    });

class _FakeReturnService extends ReturnService {
  int disputeCalls = 0;
  int withdrawCalls = 0;

  @override
  Future<ReturnRequest> show(int id) async => _rejected();

  @override
  Future<ReturnRequest> dispute(int id,
      {required String note, List<XFile> photos = const []}) async {
    disputeCalls++;
    throw const FormatException('bad body');
  }

  @override
  Future<ReturnRequest> withdraw(int id) async {
    withdrawCalls++;
    throw const FormatException('bad body');
  }
}

Future<void> _pump(WidgetTester tester, ReturnService service) async {
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
    home: ReturnDetailScreen(returnId: 77, service: service),
  ));
  await tester.pump();
  await tester.pump();
}

void main() {
  testWidgets('dispute dialog recovers from an unexpected error',
      (tester) async {
    final fake = _FakeReturnService();
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('اعتراض على القرار'));
    await tester.tap(find.text('اعتراض على القرار'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    await tester.enterText(find.byType(TextField), 'المنتج تالف فعلاً');
    await tester.tap(find.text('إرسال الاعتراض'));
    await tester.pump();
    await tester.pump();

    expect(fake.disputeCalls, 1);
    expect(find.text('تعذّر إرسال الاعتراض.'), findsOneWidget);
    // الأزرار عادت فعّالة
    final submit = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'إرسال الاعتراض'));
    expect(submit.onPressed, isNotNull);
    final cancel = tester
        .widget<TextButton>(find.widgetWithText(TextButton, 'إلغاء'));
    expect(cancel.onPressed, isNotNull);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('withdraw shows feedback on an unexpected error', (tester) async {
    final fake = _FakeReturnService();
    await _pump(tester, fake);

    await tester.ensureVisible(find.text('سحب الطلب'));
    await tester.tap(find.text('سحب الطلب'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('نعم، اسحب الطلب'));
    await tester.pump();
    await tester.pump();

    expect(fake.withdrawCalls, 1);
    expect(find.text('تعذّر سحب طلب الإرجاع.'), findsOneWidget);

    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });
}
