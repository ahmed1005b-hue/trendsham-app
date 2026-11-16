import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_analytics_screen.dart';
import 'package:trendsham/services/admin_service.dart';

Map<String, dynamic> _summary(int days) => {
      'days': days,
      'kpis': {
        'gmv': 1250000,
        'orders': 42,
        'avg_order_value': 29762,
        'commission': 125000,
        'new_customers': 7,
        'refunded': 0,
        'cancel_rate': 4.5,
      },
      'changes': {'gmv': 12, 'orders': -3, 'commission': null, 'new_customers': 0},
      'series': [
        {'date': '2026-11-15', 'gmv': 500000, 'orders': 10, 'commission': 50000, 'new_customers': 3},
        {'date': '2026-11-16', 'gmv': 750000, 'orders': 32, 'commission': 75000, 'new_customers': 4},
      ],
      'order_status': [
        {'status': 'delivered', 'label': 'تم التسليم', 'count': 30},
      ],
      'payment_methods': [
        {'method': 'card', 'label': 'بطاقة', 'count': 40, 'amount': 1200000},
      ],
      'top_sellers': [
        {'id': 1, 'name': 'Store One', 'sales': 900000, 'orders': 20, 'commission': 90000},
      ],
      'top_products': [
        {'product_id': 1, 'name': 'Product One', 'sold_count': 5, 'revenue': 50000},
      ],
      'top_categories': [],
      'users': {'customers': 100, 'sellers': 5, 'pending_sellers': 1, 'suspended_sellers': 0, 'new_sellers': 1, 'active_buyers': 30, 'repeat_buyers': 8, 'active_sellers': 4},
      'catalog': {'active_products': 60, 'pending_review': 2, 'out_of_stock': 3, 'low_stock': 4, 'categories': 8},
      'returns': {'total': 2, 'needs_action': 1, 'return_rate': 1.2, 'by_status': [], 'by_reason': []},
      'finance': {'wallets_balance': 300000, 'pending_withdrawals': 1, 'pending_withdrawals_amount': 50000, 'paid_withdrawals_amount': 0, 'settled_commission': 0, 'showcase_revenue': 1000, 'story_revenue': 500},
      'marketing': {'active_campaigns': 2, 'coupon_redemptions': 3, 'coupon_discount': 1500, 'platform_funded_discount': 1000, 'points_earned': 900, 'points_redeemed': 100, 'store_followers': 4, 'favorites': 9},
      'support': {'open_seller_tickets': 1, 'escalated_chats': 0, 'unanswered_questions': 5},
    };

class _FakeService extends AdminService {
  final requested = <int>[];
  bool fail = false;

  @override
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    requested.add(days);
    if (fail) throw const FormatException('bad');
    return _summary(days);
  }
}

Widget _app(AdminService service) => MaterialApp(
      theme: AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AdminAnalyticsScreen(service: service),
    );

void main() {
  testWidgets('shows KPIs with thousands separators and rankings',
      (tester) async {
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _FakeService();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(service.requested, [30]);
    expect(find.text('1,250,000'), findsOneWidget);
    expect(find.text('▲ 12%'), findsOneWidget);
    expect(find.text('▼ 3%'), findsOneWidget);
    expect(find.text('Store One'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('changing the window reloads with that window', (tester) async {
    final service = _FakeService();
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    await tester.tap(find.text('آخر 90 يوم'));
    await tester.pumpAndSettle();

    expect(service.requested, [30, 90]);
  });

  testWidgets('an unexpected error shows a retry message', (tester) async {
    final service = _FakeService()..fail = true;
    await tester.pumpWidget(_app(service));
    await tester.pumpAndSettle();

    expect(find.text('تعذّر تحميل التحليلات.'), findsOneWidget);
  });
}
