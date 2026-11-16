// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/main.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/theme/theme_switcher.dart';

void main() {
  testWidgets('TrendShamApp smoke test', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // Build our app with the same providers main() registers.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => AuthProvider()),
          ChangeNotifierProvider(create: (_) => CartProvider()),
          ChangeNotifierProvider(
              create: (_) => AppSettingsProvider(preferences: prefs)),
          ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
        ],
        child: const TrendShamApp(),
      ),
    );
    expect(find.byType(TrendShamApp), findsOneWidget);
  });
}
