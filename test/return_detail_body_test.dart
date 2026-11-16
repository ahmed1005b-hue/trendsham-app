import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/return_request.dart';
import 'package:trendsham/screens/returns/return_detail_body.dart';

/// refund_amount من السيرفر يشمل أجرة التوصيل؛ التفاصيل لا تضيفها مرة ثانية.
ReturnRequest _withShipping() => ReturnRequest.fromJson({
      'id': 40,
      'number': 'RT-40',
      'status': 'refunded',
      'reason': 'damaged',
      'order_id': 5,
      'refund_amount': 350,
      'shipping_refund': 50,
      'items': [
        {
          'id': 1,
          'order_item_id': 9,
          'product_name': 'قميص',
          'quantity': 3,
          'refund_amount': 300,
        }
      ],
      'refund': {
        'amount': 350,
        'method': 'bank_transfer',
        'method_label': 'حوالة بنكية',
      },
    });

Future<void> _pump(WidgetTester tester, ReturnRequest request) async {
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
    home: Scaffold(
      body: ReturnDetailBody(request: request, onRefresh: () async {}),
    ),
  ));
  await tester.pump();
}

void main() {
  testWidgets('total is the server refund amount, shipping shown as included',
      (tester) async {
    await _pump(tester, _withShipping());

    // الإجمالي (350) مرتان: بطاقة المنتجات وبطاقة الاسترداد، ولا يظهر 400
    expect(find.text('350 ل.س'), findsNWidgets(2));
    expect(find.text('400 ل.س'), findsNothing);
    expect(find.text('منها أجرة توصيل'), findsOneWidget);
    expect(find.text('50 ل.س'), findsOneWidget);
    expect(find.text('حوالة بنكية'), findsOneWidget);
    expect(find.text('bank_transfer'), findsNothing);
  });

  testWidgets('no shipping line when nothing was refunded for delivery',
      (tester) async {
    await _pump(
        tester,
        ReturnRequest.fromJson({
          'id': 41,
          'number': 'RT-41',
          'status': 'requested',
          'reason': 'changed_mind',
          'order_id': 5,
          'refund_amount': 200,
          'shipping_refund': 0,
        }));

    expect(find.text('200 ل.س'), findsOneWidget);
    expect(find.text('منها أجرة توصيل'), findsNothing);
  });
}
