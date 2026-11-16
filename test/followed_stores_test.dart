import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/models/vendor.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/screens/followed_stores/followed_stores_screen.dart';
import 'package:trendsham/screens/profile/profile_screen.dart';
import 'package:trendsham/services/store_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';

Vendor _store(int id) => Vendor.fromJson({
      'id': id,
      'store_name': 'متجر $id',
      'products_count': 3,
      'followers_count': 10,
      'is_followed': true,
    });

/// خدمة وهمية: صفحتان (20 + 1) وإلغاء متابعة يعيد false.
class _FakeStores extends StoreService {
  _FakeStores({this.pages = 1, this.perPage = 2});
  final int pages;
  final int perPage;
  final List<int> unfollowed = [];
  final List<int> requestedPages = [];

  @override
  Future<FollowedStoresResult> followedStores({int page = 1}) async {
    requestedPages.add(page);
    final start = (page - 1) * perPage;
    return FollowedStoresResult(
      stores: [
        for (var i = 1; i <= perPage; i++)
          if (!unfollowed.contains(start + i)) _store(start + i)
      ],
      currentPage: page,
      lastPage: pages,
      total: pages * perPage,
    );
  }

  @override
  Future<bool> toggleFollow(int storeId) async {
    unfollowed.add(storeId);
    return false;
  }
}

Future<void> _pump(WidgetTester tester, Widget home, {AuthProvider? auth}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(420, 1800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: auth ?? AuthProvider()),
      ChangeNotifierProvider.value(value: CartProvider()),
      ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
      ChangeNotifierProvider(create: (_) => AppSettingsProvider(preferences: prefs)),
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
      home: home,
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

void main() {
  testWidgets('profile button opens the followed stores screen', (tester) async {
    final auth = AuthProvider()
      ..updateUser(AppUser(id: 1, name: 'سارة علي', firstName: 'سارة', lastName: 'علي', phone: '0933', email: 'a@b.co', role: 'customer'));
    await _pump(tester, const ProfileScreen(), auth: auth);

    await tester.ensureVisible(find.text('المتاجر التي أتابعها'));
    await tester.tap(find.text('المتاجر التي أتابعها'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byType(FollowedStoresScreen), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('unfollow asks first, then removes the store', (tester) async {
    final fake = _FakeStores();
    await _pump(tester, FollowedStoresScreen(service: fake));

    expect(find.text('متجر 1'), findsOneWidget);
    expect(find.text('متجر 2'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'إلغاء المتابعة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('تراجع'));
    await tester.pumpAndSettle();
    expect(fake.unfollowed, isEmpty);

    await tester.tap(find.widgetWithText(OutlinedButton, 'إلغاء المتابعة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'إلغاء المتابعة'));
    await tester.pumpAndSettle();

    expect(fake.unfollowed, [1]);
    expect(find.text('متجر 1'), findsNothing);
    expect(find.text('تم إلغاء متابعة المتجر.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('loads the next page without errors', (tester) async {
    final fake = _FakeStores(pages: 2, perPage: 2);
    await _pump(tester, FollowedStoresScreen(service: fake));
    await tester.pumpAndSettle();

    expect(fake.requestedPages, [1, 2]);
    expect(find.text('متجر 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('empty state explains how to follow', (tester) async {
    await _pump(tester, FollowedStoresScreen(service: _FakeStores(perPage: 0)));
    expect(find.text('لا تتابع أي متجر حالياً.'), findsOneWidget);
    await _finish(tester);
  });
}
