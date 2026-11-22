import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/services/app_update.dart';

/// رقم الإصدار والتحديث: أقدم من المسموح ← إجباري، أقدم من الأحدث ← اختياري.
void main() {
  test('versions compare number by number, not as text', () {
    expect(compareVersions('1.10.0', '1.9.9'), greaterThan(0));
    expect(compareVersions('1.1.0', '1.1.0+5'), 0);
    expect(compareVersions('1.0', '1.0.1'), lessThan(0));
    expect(compareVersions('2.0.0', '1.99.99'), greaterThan(0));
  });

  test('older than the minimum must update, older than the latest may', () {
    const info = AppVersionInfo(latestVersion: '1.3.0', minVersion: '1.1.0');
    expect(updateNeed('1.0.9', info), UpdateNeed.required);
    expect(updateNeed('1.2.0', info), UpdateNeed.optional);
    expect(updateNeed('1.3.0', info), UpdateNeed.none);
    expect(updateNeed('1.4.0', info), UpdateNeed.none);
  });

  Future<void> pumpGate(WidgetTester tester, String current) async {
    SharedPreferences.setMockInitialValues({});
    AppUpdateGate.loader = () async => (
          current,
          const AppVersionInfo(
              latestVersion: '1.3.0',
              minVersion: '1.1.0',
              storeUrl: 'https://play.google.com/store/apps/details?id=x'),
        );
    addTearDown(() => AppUpdateGate.loader = () async => ('1.1.0', null));
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: AppUpdateGate(child: Scaffold(body: Text('home'))),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('a too-old app gets a required update it cannot dismiss',
      (tester) async {
    await pumpGate(tester, '1.0.0');
    expect(find.text('يجب تحديث التطبيق'), findsOneWidget);
    expect(find.text('لاحقاً'), findsNothing);
    expect(find.text('تحديث الآن'), findsOneWidget);
  });

  testWidgets('an older app is told about the update and may skip it',
      (tester) async {
    await pumpGate(tester, '1.2.0');
    expect(find.text('يوجد تحديث جديد'), findsOneWidget);
    await tester.tap(find.text('لاحقاً'));
    await tester.pumpAndSettle();
    expect(find.text('يوجد تحديث جديد'), findsNothing);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('update_dismissed_version'), '1.3.0');
  });

  testWidgets('an up-to-date app shows nothing', (tester) async {
    await pumpGate(tester, '1.3.0');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('the account page shows the version', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      locale: Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: AppVersionLabel()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('الإصدار 1.1.0'), findsOneWidget);
  });
}
