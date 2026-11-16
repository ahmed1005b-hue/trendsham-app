import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/utils/auth_prompt.dart';

void main() {
  testWidgets('logged-in users continue without a login prompt',
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
    var allowed = false;

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
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
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async {
                  allowed = await showAuthRequiredDialog(context);
                },
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(allowed, isTrue);
    expect(find.text('تسجيل الدخول مطلوب'), findsNothing);
  });

  testWidgets('guests still see the login prompt', (tester) async {
    final auth = AuthProvider();

    await tester.pumpWidget(
      ChangeNotifierProvider.value(
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
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () => showAuthRequiredDialog(context),
                child: const Text('Continue'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.text('تسجيل الدخول مطلوب'), findsOneWidget);
  });
}
