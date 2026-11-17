import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/screens/auth/login_screen.dart';
import 'package:trendsham/services/social_sign_in.dart';
import 'package:trendsham/theme/theme_switcher.dart';

class _FakeSocial extends SocialSignIn {
  _FakeSocial(this.providers);

  final Set<String> providers;
  final requested = <String>[];

  @override
  Future<Set<String>> availableProviders() async => providers;

  /// المستخدم ألغى نافذة Google/Facebook.
  @override
  Future<String?> token(String provider) async {
    requested.add(provider);
    return null;
  }
}

Future<void> _pump(WidgetTester tester, SocialSignIn social) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
        ChangeNotifierProvider(
            create: (_) => AppSettingsProvider(preferences: prefs)),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: LoginScreen(socialSignIn: social),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no social buttons when no provider is configured',
      (tester) async {
    await _pump(tester, _FakeSocial(const {}));
    expect(find.byKey(const ValueKey('social-google')), findsNothing);
    expect(find.byKey(const ValueKey('social-facebook')), findsNothing);
  });

  testWidgets('shows only the enabled provider; cancelling shows no error',
      (tester) async {
    final social = _FakeSocial(const {'google'});
    await _pump(tester, social);

    expect(find.byKey(const ValueKey('social-google')), findsOneWidget);
    expect(find.byKey(const ValueKey('social-facebook')), findsNothing);

    await tester.ensureVisible(find.byKey(const ValueKey('social-google')));
    await tester.tap(find.byKey(const ValueKey('social-google')));
    await tester.pumpAndSettle();

    expect(social.requested, ['google']);
    expect(find.text('تعذّر إكمال الدخول.'), findsNothing);
    expect(find.byKey(const ValueKey('social-google')), findsOneWidget);
  });

  testWidgets('both buttons when both providers are enabled', (tester) async {
    await _pump(tester, _FakeSocial(const {'google', 'facebook'}));
    expect(find.byKey(const ValueKey('social-google')), findsOneWidget);
    expect(find.byKey(const ValueKey('social-facebook')), findsOneWidget);
  });
}
