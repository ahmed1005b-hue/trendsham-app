import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/screens/auth/login_screen.dart';
import 'package:trendsham/theme/theme_switcher.dart';

/// الزائر يغيّر اللغة والمظهر من شاشة الدخول نفسها، قبل أن يملك حساباً.
void main() {
  testWidgets('login screen switches language and theme', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final theme = ThemeController(prefs: prefs);
    final settings = AppSettingsProvider(preferences: prefs);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: theme),
          ChangeNotifierProvider.value(value: settings),
        ],
        child: Consumer2<AppSettingsProvider, ThemeController>(
          builder: (_, s, t, __) => MaterialApp(
            locale: s.locale,
            themeMode: t.themeMode,
            theme: ThemeData.light(),
            darkTheme: ThemeData.dark(),
            localizationsDelegates: const [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const LoginScreen(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('تسجيل الدخول'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.translate_rounded));
    await tester.pumpAndSettle();
    // أسماء اللغات بأسمائها الأصلية
    expect(find.text('Türkçe'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();

    expect(settings.locale.languageCode, 'en');
    expect(prefs.getString('app.locale'), 'en');
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('TrendSham', findRichText: true), findsOneWidget);

    await tester.tap(find.byIcon(Icons.dark_mode_rounded));
    await tester.pumpAndSettle();
    expect(theme.themeMode, ThemeMode.dark);
  });
}
