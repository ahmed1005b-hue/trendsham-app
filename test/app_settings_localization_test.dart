import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/theme/theme_switcher.dart';

void main() {
  late L10nCatalog catalog;
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    catalog = await L10nCatalog.load();
  });

  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arabic is RTL and English and Turkish are LTR', (tester) async {
    for (final locale in AppLocalizations.supportedLocales) {
      TextDirection? resolvedDirection;
      await tester.pumpWidget(MaterialApp(
        locale: locale,
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Builder(builder: (context) {
          resolvedDirection = Directionality.of(context);
          return const SizedBox();
        }),
      ));
      await tester.pumpAndSettle();
      final direction = resolvedDirection;
      expect(
        direction,
        locale.languageCode == 'ar' ? TextDirection.rtl : TextDirection.ltr,
      );
    }
  });

  test('locale preference persists between provider instances', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final first = AppSettingsProvider(preferences: preferences);
    await first.setLocale(const Locale('tr'));

    final restored = AppSettingsProvider(preferences: preferences);
    await restored.load();

    expect(restored.locale, const Locale('tr'));
  });

  test('theme mode persists in one place for every role', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();

    final first = ThemeController(prefs: preferences);
    await first.setThemeMode(ThemeMode.system);
    expect(ThemeController(prefs: preferences).themeMode, ThemeMode.system);

    await first.setThemeMode(ThemeMode.dark);
    expect(ThemeController(prefs: preferences).themeMode, ThemeMode.dark);
  });

  test('theme migrates the old dark-mode toggle preference', () async {
    SharedPreferences.setMockInitialValues({'isDarkMode': true});
    final preferences = await SharedPreferences.getInstance();

    final controller = ThemeController(prefs: preferences);
    expect(controller.themeMode, ThemeMode.dark);

    await controller.toggleTheme();
    expect(controller.themeMode, ThemeMode.light);
    expect(preferences.getBool('isDarkMode'), isNull);
    expect(ThemeController(prefs: preferences).themeMode, ThemeMode.light);
  });

  test(
      'translation catalog supports English, Turkish, Arabic and interpolated text',
      () {
    expect(
        AppLocalizations(const Locale('en'), catalog).translate('المفضلة'), 'Favorites');
    expect(
      AppLocalizations(const Locale('tr'), catalog)
          .translate('بيانات الدخول غير صحيحة.'),
      'E-posta/telefon veya şifre hatalı.',
    );
    expect(
      AppLocalizations(const Locale('tr'), catalog).translate('كشف حساب متجر الشام'),
      'Hesap ekstresi: متجر الشام',
    );
    expect(
        AppLocalizations(const Locale('tr'), catalog).translate('المفضلة'), 'Favoriler');
    expect(
        AppLocalizations(const Locale('ar'), catalog).translate('المفضلة'), 'المفضلة');
    expect(
      AppLocalizations(const Locale('en'), catalog).translate('طلب #42'),
      'Order #42',
    );
    expect(
      AppLocalizations(const Locale('en'), catalog)
          .translate('\u0646\u0648\u0639 \u0627\u0644\u062d\u0633\u0627\u0628'),
      'Account type',
    );
    expect(
      AppLocalizations(const Locale('tr'), catalog).translate(
          '\u0637\u0644\u0628 42 \u2022 \u0627\u0644\u0643\u0645\u064a\u0629: 3'),
      'Sipari\u015f 42 \u2022 Adet: 3',
    );
    expect(
      AppLocalizations(const Locale('en'), catalog)
          .translate('\u0645\u0637\u0644\u0648\u0628'),
      'Required',
    );
    expect(
      AppLocalizations(const Locale('en'), catalog).translate('واجهة متجري'),
      'My storefront',
    );
    expect(
      AppLocalizations(const Locale('tr'), catalog).translate('4.5 (2 تقييم)'),
      '4.5 (2 değerlendirme)',
    );
  });
}
