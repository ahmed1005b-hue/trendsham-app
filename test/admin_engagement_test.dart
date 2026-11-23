import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_broadcast_screen.dart';
import 'package:trendsham/screens/admin/admin_gift_cards_screen.dart';
import 'package:trendsham/screens/admin/admin_loyalty_screen.dart';
import 'package:trendsham/services/admin_engagement_service.dart';

/// لوحة المدير في التطبيق: الإشعار الجماعي، وبطاقات الهدايا، ونقاط الولاء (مثل الموقع).
class _Fake extends AdminEngagementService {
  final calls = <String>[];
  DateTime? nextAllowed;
  int balance = 30;

  @override
  Future<BroadcastsPage> broadcasts() async => BroadcastsPage(
      total: 12, reachable: 5, nextAllowedAt: nextAllowed, items: const []);

  @override
  Future<String> sendBroadcast(
      {required String title, required String body, String? link}) async {
    calls.add('send:$title');
    return 'سيُرسل الإشعار الآن لكل العملاء.';
  }

  @override
  Future<GiftCardsPage> giftCards({String? status, String? q}) async {
    calls.add('gift:${status ?? ''}');
    return const GiftCardsPage(
      {'sold_count': 2, 'sold_amount': 70000, 'owed': 50000},
      [('active', 'فعّالة')],
      [
        GiftCardRow(
            id: 1,
            amount: 50000,
            status: 'active',
            statusLabel: 'فعّالة',
            purchaser: 'سارة'),
      ],
    );
  }

  @override
  Future<LoyaltyPage> loyalty({String? q}) async => LoyaltyPage(
        const {'outstanding': 30, 'outstanding_value': 6000},
        const {
          'loyalty_enabled': true,
          'loyalty_spend_per_point': 10000,
          'loyalty_point_value': 200,
          'loyalty_min_redeem': 10,
          'loyalty_expiry_months': 12,
          'loyalty_coupon_valid_days': 30,
        },
        [LoyaltyCustomer(userId: 4, name: 'سارة', balance: balance)],
      );

  @override
  Future<LoyaltyHistory> loyaltyCustomer(int userId) async => LoyaltyHistory(
      name: 'سارة',
      balance: balance,
      pending: 3,
      debt: 0,
      transactions: const [('إضافة من الإدارة: اختبار', 30, null)]);

  @override
  Future<String> adjustPoints(int userId,
      {required bool add, required int points, required String reason}) async {
    calls.add('adjust:$userId:${add ? '+' : '-'}$points:$reason');
    balance += add ? points : -points;
    return 'أُضيفت';
  }
}

Future<void> _open(WidgetTester tester, Widget home) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: home,
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a broadcast needs title, text and confirmation', (tester) async {
    final fake = _Fake();
    await _open(tester, AdminBroadcastScreen(service: fake));

    await tester.enterText(
        find.byKey(const ValueKey('broadcast-title')), 'تخفيضات');
    await tester.enterText(
        find.byKey(const ValueKey('broadcast-body')), 'خصومات حتى 50%');
    final send = find.byKey(const ValueKey('broadcast-send'));
    await tester.scrollUntilVisible(send, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty, reason: 'not confirmed yet');

    await tester.tap(find.byKey(const ValueKey('broadcast-confirm')));
    await tester.pump();
    await tester.tap(send);
    await tester.pumpAndSettle();
    expect(fake.calls, ['send:تخفيضات']);
  });

  testWidgets('the form is replaced by the next allowed date', (tester) async {
    final fake = _Fake()..nextAllowed = DateTime(2026, 11, 30, 9);
    await _open(tester, AdminBroadcastScreen(service: fake));

    expect(find.byKey(const ValueKey('broadcast-wait')), findsOneWidget);
    expect(find.byKey(const ValueKey('broadcast-send')), findsNothing);
  });

  testWidgets('gift cards show what the platform owes and filter by status',
      (tester) async {
    final fake = _Fake();
    await _open(tester, AdminGiftCardsScreen(service: fake));

    expect(find.textContaining('50,000'), findsWidgets);
    expect(find.text('سارة'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('gift-status-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('فعّالة').last);
    await tester.pumpAndSettle();
    expect(fake.calls.last, 'gift:active');
  });

  testWidgets('admin adds points to a customer with a reason', (tester) async {
    final fake = _Fake();
    await _open(tester, AdminLoyaltyScreen(service: fake));

    await tester.tap(find.byKey(const ValueKey('loyalty-customer-4')));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const ValueKey('loyalty-points')), '10');
    await tester.tap(find.byKey(const ValueKey('loyalty-adjust')));
    await tester.pumpAndSettle();
    expect(fake.calls, isEmpty, reason: 'reason is required');

    await tester.enterText(
        find.byKey(const ValueKey('loyalty-reason')), 'تعويض تأخير');
    await tester.tap(find.byKey(const ValueKey('loyalty-adjust')));
    await tester.pumpAndSettle();
    expect(fake.calls, ['adjust:4:+10:تعويض تأخير']);
    expect(find.text('40'), findsOneWidget);
  });
}
