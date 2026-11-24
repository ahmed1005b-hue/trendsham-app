import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/screens/home/main_screen.dart';
import 'package:trendsham/theme/theme_switcher.dart';
import 'package:trendsham/widgets/staff_session_guard.dart';

/// جلسة وهمية: تسجيل الخروج الحقيقي يلمس التخزين الآمن والإشعارات.
class _FakeAuth extends AuthProvider {
  AppUser? _signedIn;

  @override
  AppUser? get user => _signedIn;

  void signIn(AppUser user) {
    _signedIn = user;
    notifyListeners();
  }

  void signOut() {
    _signedIn = null;
    notifyListeners();
  }
}

AppUser _staff(String role) => AppUser(
      id: 7,
      name: 'Staff',
      firstName: 'Test',
      lastName: 'Staff',
      phone: '123',
      role: role,
    );

Future<void> _pumpGuarded(WidgetTester tester, _FakeAuth auth) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: auth),
      ChangeNotifierProvider.value(value: CartProvider()),
      ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
      ChangeNotifierProvider(
          create: (_) => AppSettingsProvider(preferences: prefs)),
    ],
    child: MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: StaffSessionGuard(
        role: 'seller',
        child: Builder(
          builder: (context) => Scaffold(
            body: ElevatedButton(
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const Scaffold(body: Text('صفحة داخلية')),
              )),
              child: const Text('لوحة البائع'),
            ),
          ),
        ),
      ),
    ),
  ));
}

/// إطار ينفّذ الانتقال ثم مدة تكفي لانتهاء حركة الصفحة وحذف ما خلفها.
Future<void> _finishTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump();
  await tester.pump(const Duration(seconds: 1));
}

Future<void> _flushTimers(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets('signing out of a seller account leaves for the home page',
      (tester) async {
    final auth = _FakeAuth()..signIn(_staff('seller'));
    await _pumpGuarded(tester, auth);

    await tester.tap(find.text('لوحة البائع'));
    await tester.pumpAndSettle();
    expect(find.text('صفحة داخلية'), findsOneWidget);

    auth.signOut();
    await _finishTransition(tester);

    expect(find.text('لوحة البائع'), findsNothing);
    expect(find.text('صفحة داخلية'), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);
    // لا يمكن الرجوع إلى اللوحة: الصفحة الرئيسية هي الوحيدة في المكدس
    expect(Navigator.of(tester.element(find.byType(MainScreen))).canPop(),
        isFalse);

    await _flushTimers(tester);
  });

  testWidgets('a session of another role never sees the seller dashboard',
      (tester) async {
    final auth = _FakeAuth()..signIn(_staff('customer'));
    await _pumpGuarded(tester, auth);
    await _finishTransition(tester);

    expect(find.text('لوحة البائع'), findsNothing);
    expect(find.byType(MainScreen), findsOneWidget);

    await _flushTimers(tester);
  });
}
