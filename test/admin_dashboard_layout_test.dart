import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/admin/admin_dashboard_tab.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/services/admin_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';

class _FakeAdminService extends AdminService {
  @override
  Future<Map<String, dynamic>> dashboard() async => {
        'sellers_count': 3,
        'customers_count': 10,
        'pending_sellers_count': 1,
        'identity_review_count': 0,
        'pending_products_count': 2,
        'pending_withdrawals_count': 0,
        'total_sales': 15000.0,
        'total_commission': 1500.0,
      };
}

void main() {
  for (final width in [320.0, 360.0, 412.0]) {
    for (final dark in [false, true]) {
      testWidgets(
          'quick access tiles fit at ${width.toInt()}px (${dark ? 'dark' : 'light'})',
          (tester) async {
        tester.view.physicalSize = Size(width, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        await tester.pumpWidget(ChangeNotifierProvider(
            create: (_) => ThemeController(prefs: prefs),
            child: MaterialApp(
              theme: dark ? AppTheme.dark : AppTheme.light,
              locale: const Locale('ar'),
              supportedLocales: AppLocalizations.supportedLocales,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: AdminDashboardTab(service: _FakeAdminService()),
            )));
        await tester.pumpAndSettle();

        expect(find.text('دعم البائعين'), findsOneWidget);
        expect(find.text('مساحات العرض'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('theme toggle on the admin home switches the whole app',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final controller =
        ThemeController(prefs: await SharedPreferences.getInstance());

    // نفس ربط main.dart: MaterialApp يقرأ وضعه من ThemeController
    await tester.pumpWidget(ChangeNotifierProvider.value(
      value: controller,
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: theme.themeMode,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: AdminDashboardTab(service: _FakeAdminService()),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    Brightness brightness() =>
        Theme.of(tester.element(find.byType(AdminDashboardTab))).brightness;
    expect(brightness(), Brightness.light);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    expect(controller.themeMode, ThemeMode.dark);

    await tester.tap(find.byType(ThemeToggleButton));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(tester.takeException(), isNull);
  });
}
