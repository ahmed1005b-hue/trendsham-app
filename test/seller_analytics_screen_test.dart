import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/seller/seller_analytics_screen.dart';
import 'package:trendsham/services/seller_service.dart';

/// مؤشرات الأداء للبائع في التطبيق: نفس صفحة الإحصائيات في الموقع.
class _FakeSellerService extends SellerService {
  final requestedDays = <int>[];

  @override
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    requestedDays.add(days);
    return {
      'days': days,
      'totals': {
        'sales': 250000,
        'net_profit': 225000,
        'commission': 25000,
        'orders': 4,
        'items_sold': 6,
        'avg_order_value': 62500,
      },
      'changes': {'sales': 20, 'net_profit': -5},
      'series': [
        {'date': '2026-11-22', 'sales': 100000, 'net_profit': 90000},
        {'date': '2026-11-23', 'sales': 150000, 'net_profit': 135000},
      ],
      'status_breakdown': [
        {'status': 'pending', 'label': 'قيد المراجعة', 'count': 1},
        {'status': 'delivered', 'label': 'تم التسليم', 'count': 3},
      ],
      'wallet': {
        'balance': -12000,
        'transactions': [
          {
            'amount': -12000,
            'balance_after': -12000,
            'reason': 'عمولة طلب',
            'date': '2026-11-23 10:00'
          },
        ],
      },
      'top_products': [
        {
          'product_id': 1,
          'name': 'قميص قطن',
          'sold_count': 5,
          'revenue': 200000
        },
      ],
    };
  }
}

void main() {
  testWidgets('shows totals, statuses, top products and wallet; period changes',
      (tester) async {
    final service = _FakeSellerService();
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SellerAnalyticsScreen(service: service),
    ));
    await tester.pumpAndSettle();

    expect(service.requestedDays, [30]);
    expect(find.textContaining('250,000'), findsOneWidget);
    expect(find.textContaining('62,500'), findsOneWidget);
    expect(find.text('▲ 20%'), findsOneWidget);

    final list = find.byType(Scrollable).first;
    await tester.scrollUntilVisible(find.text('قميص قطن'), 300,
        scrollable: list);
    expect(find.text('قميص قطن'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('عمولة طلب'), 300,
        scrollable: list);
    expect(find.text('عمولة طلب'), findsOneWidget);

    await tester.scrollUntilVisible(
        find.byKey(const ValueKey('analytics-days')), -300,
        scrollable: list);
    await tester.tap(find.textContaining('90'));
    await tester.pumpAndSettle();
    expect(service.requestedDays, [30, 90]);
  });
}
