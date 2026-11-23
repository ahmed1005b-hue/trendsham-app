import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/screens/auth/register_screen.dart';
import 'package:trendsham/theme/theme_switcher.dart';

void main() {
  testWidgets(
      'sign-up is for customers; sellers and employees use an invitation',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      // زرّا اللغة والمظهر في شريط الشاشة يحتاجان مزوّديهما كما في التطبيق
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
          ChangeNotifierProvider(
              create: (_) => AppSettingsProvider(preferences: prefs)),
        ],
        child: const MaterialApp(
          locale: Locale('ar'),
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: RegisterScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(RegisterScreen), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
    expect(find.byType(Form), findsOneWidget);
    // لا سؤال «نوع الحساب»: إنشاء الحساب للعملاء، والبائع والموظف بدعوة
    expect(find.byType(DropdownButtonFormField<String>), findsNothing);
    expect(find.text('اختيار صورة الهوية'), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('invitation-open')));
    await tester.tap(find.byKey(const ValueKey('invitation-open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('invitation-code')), findsOneWidget);
    expect(find.text('رمز أو رابط الدعوة'), findsOneWidget);
  });
}
