import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/screens/profile/account_management_screen.dart';
import 'package:trendsham/services/account_service.dart';
import 'package:trendsham/services/api_exception.dart';

class _FakeAccount extends AccountService {
  _FakeAccount(this.state, {this.deleteResult = 'scheduled', this.deleteError});
  AccountClosureStatus state;
  final String deleteResult;
  final String? deleteError;
  String? deletedWith;
  String? deactivatedWith;

  @override
  Future<AccountClosureStatus> status() async => state;

  @override
  Future<String> deactivate({String? password}) async {
    deactivatedWith = password;
    return 'تم إيقاف حسابك.';
  }

  @override
  Future<({String result, String message})> delete({String? password}) async {
    if (deleteError != null) throw ApiException(deleteError!);
    deletedWith = password;
    if (deleteResult == 'requested') {
      state = AccountClosureStatus(role: state.role, canSelfDelete: false, deletionRequestedAt: DateTime(2026));
    }
    return (result: deleteResult, message: deleteResult == 'scheduled' ? 'أُغلق حسابك.' : 'وصل طلبك إلى الإدارة.');
  }
}

AppUser _user(String role) => AppUser(
    id: 1, name: 'سارة علي', firstName: 'سارة', lastName: 'علي', phone: '0933', email: 'a@b.co', role: role);

Future<AuthProvider> _pump(WidgetTester tester, AccountService service, {String role = 'customer'}) async {
  SharedPreferences.setMockInitialValues({});
  FlutterSecureStorage.setMockInitialValues({'auth_token': 'abc'});
  tester.view.physicalSize = const Size(420, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final auth = AuthProvider()..updateUser(_user(role));
  await tester.pumpWidget(ChangeNotifierProvider.value(
    value: auth,
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: TextButton(
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AccountManagementScreen(service: service))),
              child: const Text('افتح'),
            ),
          ),
        ),
      ),
    ),
  ));
  await tester.pumpAndSettle(); // تحميل الترجمة قبل أول إطار
  await tester.tap(find.text('افتح'));
  await tester.pumpAndSettle();
  return auth;
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

TextButton _dialogAction(WidgetTester tester, String label) =>
    tester.widget<TextButton>(find.descendant(of: find.byType(AlertDialog), matching: find.widgetWithText(TextButton, label)));

void main() {
  testWidgets('customer deletes after password + typing the word, then is signed out', (tester) async {
    final fake = _FakeAccount(const AccountClosureStatus(role: 'customer', canSelfDelete: true));
    final auth = await _pump(tester, fake);

    expect(find.text('إيقاف الحساب مؤقتاً'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'حذف حسابي'));
    await tester.pumpAndSettle();

    // الزر معطّل حتى تكتمل كلمة السر وكلمة التأكيد
    expect(_dialogAction(tester, 'حذف حسابي').onPressed, isNull);
    await tester.enterText(find.byKey(const Key('closure-password')), 'Secret#123');
    await tester.enterText(find.byKey(const Key('closure-confirm')), 'نعم');
    await tester.pump();
    expect(_dialogAction(tester, 'حذف حسابي').onPressed, isNull);
    await tester.enterText(find.byKey(const Key('closure-confirm')), 'حذف');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('حذف حسابي')));
    await tester.pumpAndSettle();

    expect(fake.deletedWith, 'Secret#123');
    expect(auth.user, isNull);
    expect(find.byType(AccountManagementScreen), findsNothing); // عاد للبداية
    expect(find.text('أُغلق حسابك.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('open orders disable deletion and explain why', (tester) async {
    await _pump(
        tester,
        _FakeAccount(const AccountClosureStatus(
            role: 'customer', canSelfDelete: true, blockers: ['لديك 1 طلب قيد التنفيذ.'])));

    expect(find.text('لديك 1 طلب قيد التنفيذ.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'حذف حسابي')).onPressed, isNull);
    await _finish(tester);
  });

  testWidgets('deactivate without a password for SMS-only accounts', (tester) async {
    final fake = _FakeAccount(const AccountClosureStatus(role: 'customer', canSelfDelete: true, hasPassword: false));
    final auth = await _pump(tester, fake);

    await tester.tap(find.widgetWithText(OutlinedButton, 'إيقاف الحساب'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closure-password')), findsNothing);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('إيقاف الحساب')));
    await tester.pumpAndSettle();

    expect(fake.deactivatedWith, isNull);
    expect(auth.user, isNull);
    await _finish(tester);
  });

  testWidgets('a seller sends a request and stays signed in', (tester) async {
    final fake = _FakeAccount(const AccountClosureStatus(role: 'seller', canSelfDelete: false),
        deleteResult: 'requested');
    final auth = await _pump(tester, fake, role: 'seller');

    await tester.tap(find.widgetWithText(FilledButton, 'إرسال طلب الحذف'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('closure-confirm')), findsNothing); // لا كلمة تأكيد: مجرد طلب
    await tester.enterText(find.byKey(const Key('closure-password')), 'x');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('إرسال الطلب')));
    await tester.pumpAndSettle();

    expect(auth.user, isNotNull);
    expect(find.text('أرسلت طلب الحذف، والإدارة ستتواصل معك لإتمامه.'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'إرسال طلب الحذف')).onPressed, isNull);
    await _finish(tester);
  });

  testWidgets('server refusal is shown and the session stays', (tester) async {
    final fake = _FakeAccount(const AccountClosureStatus(role: 'customer', canSelfDelete: true),
        deleteError: 'كلمة السر غير صحيحة.');
    final auth = await _pump(tester, fake);

    await tester.tap(find.widgetWithText(FilledButton, 'حذف حسابي'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('closure-password')), 'bad');
    await tester.enterText(find.byKey(const Key('closure-confirm')), 'حذف');
    await tester.pump();
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('حذف حسابي')));
    await tester.pumpAndSettle();

    expect(find.text('كلمة السر غير صحيحة.'), findsOneWidget);
    expect(auth.user, isNotNull);
    await _finish(tester);
  });

  test('status parses the server payload', () {
    final s = AccountClosureStatus.fromJson({
      'role': 'customer',
      'can_self_delete': true,
      'blockers': ['x'],
      'has_password': false,
      'grace_days': 30,
      'deletion_requested_at': null,
    });
    expect(s.canSelfDelete, isTrue);
    expect(s.blockers, ['x']);
    expect(s.hasPassword, isFalse);
    expect(s.deletionRequestedAt, isNull);
  });
}
