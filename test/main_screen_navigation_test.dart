import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/screens/home/main_screen.dart';
import 'package:trendsham/theme/theme_switcher.dart';

Future<void> _pumpMainScreen(
  WidgetTester tester, {
  AuthProvider? authProvider,
  CartProvider? cartProvider,
  ThemeData? theme,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: authProvider ?? AuthProvider()),
        ChangeNotifierProvider.value(value: cartProvider ?? CartProvider()),
        ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
      ],
      child: MaterialApp(
        locale: const Locale('ar'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: theme ?? ThemeData.light(useMaterial3: true),
        home: const MainScreen(
          tabOverrides: [
            Center(child: Text('صفحة الرئيسية')),
            Center(child: Text('صفحة الطلبات')),
            Center(child: Text('صفحة المفضلة')),
            Center(child: Text('صفحة السلة')),
            Center(child: Text('صفحة الحساب')),
          ],
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

double _contrastRatio(Color a, Color b) {
  final luminance = [a.computeLuminance(), b.computeLuminance()]..sort();
  return (luminance[1] + 0.05) / (luminance[0] + 0.05);
}

Finder _navigationLabel(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

void main() {
  testWidgets('shows five destinations in the reference left-to-right order',
      (tester) async {
    tester.view.physicalSize = const Size(360, 780);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMainScreen(tester);

    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 0);
    expect(bar.destinations, hasLength(5));

    const leftToRight = ['حسابي', 'السلة', 'المفضلة', 'طلباتي', 'الرئيسية'];
    for (final label in leftToRight) {
      expect(_navigationLabel(label), findsOneWidget);
    }

    final positions = leftToRight
        .map((label) => tester.getCenter(_navigationLabel(label)).dx)
        .toList();
    expect(positions, orderedEquals([...positions]..sort()));
  });

  testWidgets('navigates to Favorites and retains the selected destination',
      (tester) async {
    await _pumpMainScreen(tester);

    await tester.tap(_navigationLabel('المفضلة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
    expect(find.text('صفحة المفضلة'), findsOneWidget);
  });

  testWidgets('shows the filled icon only for the selected destination',
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

    await _pumpMainScreen(
      tester,
      authProvider: auth,
      cartProvider: _TrackingCartProvider(),
    );

    final navigationBar = find.byType(NavigationBar);
    expect(
      find.descendant(
          of: navigationBar, matching: find.byIcon(Icons.home_rounded)),
      findsOneWidget,
    );

    const destinations = [
      (
        label: 'طلباتي',
        index: 1,
        outlinedIcon: Icons.inventory_2_outlined,
        filledIcon: Icons.inventory_2_rounded,
      ),
      (
        label: 'المفضلة',
        index: 2,
        outlinedIcon: Icons.favorite_border_rounded,
        filledIcon: Icons.favorite_rounded,
      ),
      (
        label: 'السلة',
        index: 3,
        outlinedIcon: Icons.shopping_cart_outlined,
        filledIcon: Icons.shopping_cart_rounded,
      ),
      (
        label: 'حسابي',
        index: 4,
        outlinedIcon: Icons.person_outline_rounded,
        filledIcon: Icons.person_rounded,
      ),
    ];

    for (final destination in destinations) {
      await tester.tap(_navigationLabel(destination.label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        tester.widget<NavigationBar>(navigationBar).selectedIndex,
        destination.index,
      );
      expect(
        find.descendant(
          of: navigationBar,
          matching: find.byIcon(destination.filledIcon),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: navigationBar,
          matching: find.byIcon(destination.outlinedIcon),
        ),
        findsNothing,
      );
    }
  });

  testWidgets('keeps Cart and Orders behind the login prompt for guests',
      (tester) async {
    await _pumpMainScreen(tester);

    for (final label in ['السلة', 'طلباتي']) {
      await tester.tap(_navigationLabel(label));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('تسجيل الدخول مطلوب'), findsOneWidget);

      await tester.tap(find.text('إلغاء'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    }
  });

  testWidgets('loads Cart and opens Orders for authenticated customers',
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
    final cart = _TrackingCartProvider();

    await _pumpMainScreen(
      tester,
      authProvider: auth,
      cartProvider: cart,
    );
    expect(cart.loadCount, 1);

    await tester.tap(_navigationLabel('السلة'));
    await tester.pump();

    expect(cart.loadCount, 2);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      3,
    );

    await tester.tap(_navigationLabel('طلباتي'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      1,
    );
    expect(find.text('صفحة الطلبات'), findsOneWidget);
    // التبويبات الوسيطة أثناء الحركة لا تعيد تحميل السلة.
    expect(cart.loadCount, 2);
  });

  testWidgets('uses theme surfaces and accessible selected-state colors',
      (tester) async {
    for (final theme in [
      ThemeData.light(useMaterial3: true),
      ThemeData.dark(useMaterial3: true),
    ]) {
      await _pumpMainScreen(tester, theme: theme);

      final navigationTheme =
          tester.widget<NavigationBarTheme>(find.byType(NavigationBarTheme));
      final surface = theme.colorScheme.surface;
      final selectedLabel = navigationTheme.data.labelTextStyle!
          .resolve({WidgetState.selected})!.color!;
      final selectedIcon = navigationTheme.data.iconTheme!
          .resolve({WidgetState.selected})!.color!;
      expect(_contrastRatio(selectedLabel, surface), greaterThanOrEqualTo(4.5));
      expect(_contrastRatio(selectedIcon, surface), greaterThanOrEqualTo(3));
    }
  });

  testWidgets('guest moving to Favorites is not asked to log in for Orders',
      (tester) async {
    await _pumpMainScreen(tester);

    await tester.tap(_navigationLabel('المفضلة'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('تسجيل الدخول مطلوب'), findsNothing);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('fits all destinations at narrow mobile width', (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await _pumpMainScreen(tester);

    for (final label in ['حسابي', 'السلة', 'المفضلة', 'طلباتي', 'الرئيسية']) {
      final rect = tester.getRect(_navigationLabel(label));
      expect(rect.left, greaterThanOrEqualTo(0));
      expect(rect.right, lessThanOrEqualTo(320));
    }
    expect(tester.takeException(), isNull);
  });
}

class _TrackingCartProvider extends CartProvider {
  int loadCount = 0;

  @override
  Future<void> load() async {
    loadCount++;
  }
}
