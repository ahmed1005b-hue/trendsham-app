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
  testWidgets('seller registration asks for a private identity image',
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
    final accountTypeField = tester.widget<DropdownButtonFormField<String>>(
      find.byWidgetPredicate(
        (widget) =>
            widget.runtimeType.toString().startsWith('DropdownButtonFormField'),
      ),
    );
    accountTypeField.onChanged?.call('seller');
    await tester.pumpAndSettle();

    expect(
        find.text('صورة هوية وطنية أو صفحة بيانات جواز السفر'), findsOneWidget);
    expect(find.textContaining('تُتاح للإدارة فقط'), findsOneWidget);
    expect(find.text('اختيار صورة الهوية'), findsOneWidget);
  });
}
