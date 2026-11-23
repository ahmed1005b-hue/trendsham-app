import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/return_request.dart';
import 'package:trendsham/screens/admin/admin_debts_screen.dart';
import 'package:trendsham/screens/admin/admin_returns_screen.dart';
import 'package:trendsham/screens/admin/admin_seller_coupons_screen.dart';
import 'package:trendsham/screens/admin/admin_settings_screen.dart';
import 'package:trendsham/services/admin_review_service.dart';
import 'package:trendsham/services/admin_service.dart';

/// لوحة المدير في التطبيق: ديون المتاجر، والمرتجعات، وكوبونات البائعين، والإعدادات (مثل الموقع).
class _FakeReviews extends AdminReviewService {
  final calls = <String>[];
  String returnStatus = 'escalated';

  @override
  Future<StoreDebtsPage> debts() async => const StoreDebtsPage([
        StoreDebt(
            sellerProfileId: 7,
            storeName: 'متجر سام',
            debt: 25000,
            ownerName: 'سام'),
      ], 25000, 100000);

  @override
  Future<String> payDebt(int sellerProfileId, double amount,
      {String? note}) async {
    calls.add('pay:$sellerProfileId:${amount.toStringAsFixed(0)}');
    return 'تم تسجيل التسديد وإضافته لرصيد المتجر.';
  }

  Map<String, dynamic> _return() => {
        'id': 3,
        'number': 'RT-0003',
        'status': returnStatus,
        'status_label': 'تحت مراجعة الإدارة',
        'reason': 'damaged',
        'reason_label': 'المنتج تالف',
        'order_id': 9,
        'store_name': 'متجر سام',
        'customer_name': 'سارة',
        'refund_amount': 10000,
        'items': [],
        'events': [],
      };

  @override
  Future<AdminReturnsPage> returns({String tab = 'escalated'}) async {
    calls.add('returns:$tab');
    return AdminReturnsPage([ReturnRequest.fromJson(_return())], 1, 0);
  }

  @override
  Future<AdminReturn> showReturn(int id) async => AdminReturn.fromJson({
        'data': _return(),
        'actions': {'decide': returnStatus == 'escalated'},
      });

  @override
  Future<AdminReturn> approveReturn(int id, {String? note}) async {
    calls.add('approve:$id');
    returnStatus = 'approved';
    return AdminReturn.fromJson({
      'data': _return(),
      'actions': {'confirm_received': true},
    });
  }

  @override
  Future<SellerCouponsPage> sellerCoupons({String? status}) async =>
      const SellerCouponsPage(
          [
            SellerCouponReview(
                id: 5,
                title: 'خصم 70%',
                status: 'pending_review',
                statusLabel: 'بانتظار موافقة الإدارة',
                storeName: 'متجر سام'),
          ],
          1,
          [('pending_review', 'بانتظار موافقة الإدارة')]);

  @override
  Future<String> reviewCoupon(int id, String action, {String? reason}) async {
    calls.add('$action:$id:${reason ?? ''}');
    return 'ok';
  }
}

class _FakeAdmin extends AdminService {
  Map<String, num>? saved;

  @override
  Future<Map<String, dynamic>> settings() async => {
        'commission_rate': 10,
        'story_fee': 500,
        'seller_debt_limit': 100000,
        'self_delivery_min_orders': 5,
      };

  @override
  Future<void> updateSettings(Map<String, num> values) async => saved = values;
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
  testWidgets('admin records a store debt payment', (tester) async {
    final fake = _FakeReviews();
    await _open(tester, AdminDebtsScreen(service: fake));

    expect(find.textContaining('25,000'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('debt-7')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('debt-amount')), '10000');
    await tester.tap(find.byKey(const ValueKey('debt-pay-confirm')));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('pay:7:10000'));
  });

  testWidgets('admin approves an escalated return', (tester) async {
    final fake = _FakeReviews();
    await _open(tester, AdminReturnsScreen(service: fake));

    expect(fake.calls, contains('returns:escalated'));
    await tester.tap(find.byKey(const ValueKey('admin-return-3')));
    await tester.pumpAndSettle();

    final approve = find.byKey(const ValueKey('admin-return-approve'));
    await tester.scrollUntilVisible(approve, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(approve);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('return-note-send')));
    await tester.pumpAndSettle();

    expect(fake.calls, contains('approve:3'));
    expect(find.byKey(const ValueKey('admin-return-approve')), findsNothing);
  });

  testWidgets('rejecting a seller coupon asks for a reason', (tester) async {
    final fake = _FakeReviews();
    await _open(tester, AdminSellerCouponsScreen(service: fake));

    await tester.tap(find.byKey(const ValueKey('coupon-reject-5')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('coupon-reason-send')));
    await tester.pumpAndSettle();
    expect(fake.calls.where((c) => c.startsWith('reject')), isEmpty);

    await tester.enterText(
        find.byKey(const ValueKey('coupon-reason')), 'خصم مبالغ فيه');
    await tester.tap(find.byKey(const ValueKey('coupon-reason-send')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('reject:5:خصم مبالغ فيه'));

    await tester.tap(find.byKey(const ValueKey('coupon-approve-5')));
    await tester.pumpAndSettle();
    expect(fake.calls, contains('approve:5:'));
  });

  testWidgets('settings show debt rules and save only known fields',
      (tester) async {
    final fake = _FakeAdmin();
    await _open(tester, AdminSettingsScreen(service: fake));

    final limit = find.byKey(const ValueKey('setting-seller_debt_limit'));
    await tester.scrollUntilVisible(limit, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(limit, '50000');
    // حقل لا يعرفه هذا الخادم لا يظهر
    expect(find.byKey(const ValueKey('setting-shipping_parcel_fee')),
        findsNothing);

    final save = find.byKey(const ValueKey('settings-save'));
    await tester.scrollUntilVisible(save, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(fake.saved, {
      'commission_rate': 10,
      'story_fee': 500,
      'seller_debt_limit': 50000,
      'self_delivery_min_orders': 5,
    });
  });
}
