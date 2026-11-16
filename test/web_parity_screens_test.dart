import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/screens/admin/admin_accounting_screen.dart';
import 'package:trendsham/screens/admin/admin_daily_deals_screen.dart';
import 'package:trendsham/screens/admin/admin_shipping_companies_screen.dart';
import 'package:trendsham/screens/admin/admin_showcases_screen.dart';
import 'package:trendsham/screens/admin/admin_support_screen.dart';
import 'package:trendsham/screens/seller/seller_questions_screen.dart';
import 'package:trendsham/screens/seller/seller_showcases_screen.dart';
import 'package:trendsham/services/admin_operations_service.dart';
import 'package:trendsham/services/seller_service.dart';

/// شاشات التطبيق التي تقابل صفحات الويب (المدير والبائع).
class _FakeAdminOps extends AdminOperationsService {
  final calls = <String>[];
  final companies = <Map<String, dynamic>>[
    {'id': 1, 'name': 'شحن سريع', 'phone': '011', 'is_active': true},
  ];

  @override
  Future<List<Map<String, dynamic>>> shippingCompanies() async =>
      List.of(companies);

  @override
  Future<void> toggleShippingCompany(int id) async {
    calls.add('toggle:$id');
    companies[0] = {...companies[0], 'is_active': false};
  }

  @override
  Future<List<Map<String, dynamic>>> dailyDeals() async => [
        {
          'id': 3,
          'product_name': 'قميص كتان',
          'discount_percentage': 20,
          'special_price': null,
          'starts_at': '2026-11-10T10:00:00Z',
          'ends_at': '2026-11-12T10:00:00Z',
          'is_active': true,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> supportConversations() async => [
        {
          'id': 5,
          'subject': 'مشكلة في السحب',
          'store_name': 'متجر النخبة',
          'status': 'open',
          'last_message': 'لم يصلني المبلغ',
          'unread_count': 2,
        },
      ];

  @override
  Future<List<Map<String, dynamic>>> showcases({String? status}) async {
    calls.add('showcases:$status');
    return [
      {
        'id': 7,
        'status': 'pending_review',
        'slot': 'أعلى الرئيسية',
        'store_name': 'متجر النخبة',
        'title': 'عروض الشتاء',
        'start_date': '2026-11-20',
        'end_date': '2026-11-25',
        'amount': 30000,
        'impressions': 0,
        'clicks': 0,
      },
    ];
  }

  @override
  Future<void> approveShowcase(int id) async => calls.add('approve:$id');

  @override
  Future<List<Map<String, dynamic>>> showcaseSlots() async => const [];

  @override
  Future<Map<String, dynamic>> accounting(DateTime from, DateTime to) async => {
        'totals': {
          'sales': 1500,
          'commissions': 150,
          'refunds': 0,
          'payouts': 0,
          'showcase': 0,
          'owed_to_sellers': 1350,
        },
      };

  @override
  Future<List<Map<String, dynamic>>> accountingSellers({String? q}) async => [
        {
          'id': 9,
          'name': 'أحمد',
          'phone': '0999',
          'store_name': 'متجر النخبة',
          'balance': 1350,
        },
      ];
}

class _FakeSellerService extends SellerService {
  final answered = <int, String>{};

  @override
  Future<List<Map<String, dynamic>>> questions() async => [
        {
          'id': 1,
          'product_name': 'قميص كتان',
          'customer_name': 'سارة',
          'question': 'هل يتوفر مقاس كبير؟',
          'has_answer': false,
          'answers': const [],
        },
        {
          'id': 2,
          'product_name': 'حذاء',
          'customer_name': 'علي',
          'question': 'ما بلد الصنع؟',
          'has_answer': true,
          'answers': [
            {'answer': 'تركيا', 'is_seller_answer': true},
          ],
        },
      ];

  @override
  Future<void> answerQuestion(int questionId, String answer) async =>
      answered[questionId] = answer;

  @override
  Future<List<Product>> products() async => const [];
}

Future<void> _pump(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(400, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: screen,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('admin toggles a shipping company', (tester) async {
    final ops = _FakeAdminOps();
    await _pump(tester, AdminShippingCompaniesScreen(service: ops));

    expect(find.text('شحن سريع'), findsOneWidget);
    await tester.tap(find.byType(Switch));
    await tester.pumpAndSettle();

    expect(ops.calls, contains('toggle:1'));
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  testWidgets('admin sees daily deals and support conversations',
      (tester) async {
    final ops = _FakeAdminOps();
    await _pump(tester, AdminDailyDealsScreen(service: ops));
    expect(find.text('قميص كتان'), findsOneWidget);
    expect(find.textContaining('خصم 20%'), findsOneWidget);

    await _pump(tester, AdminSupportScreen(service: ops));
    expect(find.text('مشكلة في السحب'), findsOneWidget);
    expect(find.text('2'), findsOneWidget); // عدد غير المقروء
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin approves a pending showcase booking', (tester) async {
    final ops = _FakeAdminOps();
    await _pump(tester, AdminShowcasesScreen(service: ops));

    expect(ops.calls, contains('showcases:pending_review'));
    expect(find.textContaining('متجر النخبة'), findsOneWidget);
    await tester.tap(find.text('موافقة'));
    await tester.pumpAndSettle();

    expect(ops.calls, contains('approve:7'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('admin accounting shows totals and seller balances',
      (tester) async {
    await _pump(tester, AdminAccountingScreen(service: _FakeAdminOps()));

    expect(find.text('مستحق للبائعين'), findsOneWidget);
    expect(find.text('1,500 ل.س'), findsOneWidget);
    expect(find.text('متجر النخبة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('seller answers an unanswered customer question', (tester) async {
    final service = _FakeSellerService();
    await _pump(tester, SellerQuestionsScreen(service: service));

    // الافتراضي: غير المُجاب عنها فقط
    expect(find.text('هل يتوفر مقاس كبير؟'), findsOneWidget);
    expect(find.text('ما بلد الصنع؟'), findsNothing);

    await tester.tap(find.text('رد'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'نعم متوفر');
    await tester.tap(find.text('نشر الرد'));
    await tester.pumpAndSettle();

    expect(service.answered[1], 'نعم متوفر');
  });

  testWidgets('showcase booking validates the period before submitting',
      (tester) async {
    await _pump(
        tester, SellerShowcaseCreateScreen(service: _FakeSellerService()));

    await tester.scrollUntilVisible(find.text('إرسال الحجز'), 200,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('إرسال الحجز'));
    await tester.pumpAndSettle();

    expect(find.text('اختر فترة العرض.'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
