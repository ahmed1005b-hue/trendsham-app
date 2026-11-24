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
import 'package:trendsham/screens/coupons/my_coupons_screen.dart';
import 'package:trendsham/screens/profile/profile_screen.dart';
import 'package:trendsham/theme/theme_switcher.dart';

Future<void> _pumpProfile(WidgetTester tester, AuthProvider auth) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(400, 1600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth),
      ChangeNotifierProvider.value(value: CartProvider()),
      ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
      ChangeNotifierProvider(create: (_) => AppSettingsProvider(preferences: prefs)),
    ],
    child: const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: ProfileScreen(),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  testWidgets('coupons shortcut opens "كوبوناتي" for a signed-in customer',
      (tester) async {
    final auth = AuthProvider()
      ..updateUser(AppUser(
        id: 1,
        name: 'Customer',
        firstName: 'Test',
        lastName: 'Customer',
        phone: '123',
        role: 'customer',
      ));
    await _pumpProfile(tester, auth);

    await tester.tap(find.text('الكوبونات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MyCouponsScreen), findsOneWidget);
    // لم تعد تظهر رسالة "استعرض الكوبونات..." بدل فتح الشاشة
    expect(find.text('استعرض الكوبونات المتاحة عند إتمام الطلب'), findsNothing);

    // شاشة الكوبونات تبدأ طلباً بمهلة انتظار: نُنهيها حتى لا يبقى مؤقت معلّق
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(minutes: 1));
  });

  testWidgets('coupons shortcut asks a guest to sign in instead of opening',
      (tester) async {
    await _pumpProfile(tester, AuthProvider());

    await tester.tap(find.text('الكوبونات'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(MyCouponsScreen), findsNothing);
    expect(find.byType(Dialog).evaluate().isNotEmpty ||
        find.byType(AlertDialog).evaluate().isNotEmpty ||
        find.byType(BottomSheet).evaluate().isNotEmpty, isTrue);
  });

  for (final role in ['seller', 'admin', 'employee']) {
    testWidgets('$role account page hides the shopping sections',
        (tester) async {
      final auth = AuthProvider()
        ..updateUser(AppUser(
          id: 2,
          name: 'Staff',
          firstName: 'Test',
          lastName: 'Staff',
          phone: '123',
          role: role,
        ));
      await _pumpProfile(tester, auth);

      for (final shoppingItem in [
        'طلباتي',
        'الكوبونات',
        'المفضلة',
        'المتاجر التي أتابعها',
        'عناويني',
        'كوبوناتي',
        'أكمل ملفك التعريفي',
      ]) {
        expect(find.text(shoppingItem), findsNothing, reason: shoppingItem);
      }
      expect(find.text('تعديل البيانات الشخصية'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });
  }
}
