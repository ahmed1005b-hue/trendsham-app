import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/user.dart';
import 'package:trendsham/models/user_address.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/screens/profile/my_addresses_screen.dart';
import 'package:trendsham/screens/profile/profile_screen.dart';
import 'package:trendsham/services/address_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';
import 'package:trendsham/utils/profile_completion.dart';

UserAddress _addr(int id, {String label = 'home', bool isDefault = false}) => UserAddress(
      id: id,
      label: label,
      labelText: UserAddress.labels[label]!,
      city: 'دمشق',
      details: 'المزة $id',
      isDefault: isDefault,
      shippingText: 'دمشق - المزة $id',
    );

AppUser _user({
  String? email = 'a@b.co',
  String? avatar,
  String? birthDate,
  String? gender,
  bool phoneVerified = false,
  UserAddress? defaultAddress,
}) =>
    AppUser(
      id: 1,
      name: 'سارة علي',
      firstName: 'سارة',
      lastName: 'علي',
      phone: '0933',
      email: email,
      avatar: avatar,
      birthDate: birthDate,
      gender: gender,
      role: 'customer',
      phoneVerified: phoneVerified,
      defaultAddress: defaultAddress,
    );

/// خدمة وهمية تحفظ في الذاكرة وتسجّل ما أُرسل.
class _FakeAddresses extends AddressService {
  _FakeAddresses(this.items);
  final List<UserAddress> items;
  Map<String, dynamic>? created;
  ({String city, String details})? suggestion;

  @override
  Future<({String city, String details})?> reverseGeocode(double lat, double lng) async => suggestion;

  @override
  Future<List<UserAddress>> list() async => List.of(items);

  @override
  Future<UserAddress> create({
    required String label,
    required String city,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    created = {
      'label': label,
      'city': city,
      'details': details,
      'latitude': latitude,
      'longitude': longitude,
      'is_default': isDefault,
    };
    final a = UserAddress(
      id: items.length + 1,
      label: label,
      labelText: UserAddress.labels[label]!,
      city: city,
      details: details,
      latitude: latitude,
      longitude: longitude,
      isDefault: isDefault,
      shippingText: '$city - $details',
    );
    items.add(a);
    return a;
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
  await tester.pump(); // إطار إضافي: البيانات تصل بعد أول بناء
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1)); // مهلات طلبات الشبكة في الاختبار
}

void main() {
  group('ProfileCompletion', () {
    test('counts real fields, including a shipping address', () {
      final bare = ProfileCompletion.of(_user());
      expect(bare.done, 2); // الاسم + البريد
      expect(bare.percent, 33);
      expect(bare.isComplete, isFalse);

      final full = ProfileCompletion.of(_user(
        avatar: 'https://x/a.jpg',
        birthDate: '1990-01-01',
        gender: 'female',
        defaultAddress: _addr(1, isDefault: true),
      ));
      expect(full.percent, 100);
      expect(full.isComplete, isTrue);
    });

    test('knows when only the address is missing', () {
      final c = ProfileCompletion.of(_user(
          avatar: 'https://x/a.jpg', birthDate: '1990-01-01', gender: 'male'));
      expect(c.onlyAddressMissing, isTrue);
      expect(c.missing.single.label, 'عنوان الشحن');
    });
  });

  test('AppUser reads verification and the default address from the API', () {
    final u = AppUser.fromJson({
      'id': 3,
      'name': 'x',
      'role': 'customer',
      'phone_verified': true,
      'addresses_count': 2,
      'default_address': {
        'id': 9,
        'label': 'work',
        'label_text': 'العمل',
        'city': 'حلب',
        'details': 'الفرقان',
        'latitude': 36.2,
        'longitude': 37.1,
        'map_url': 'https://www.google.com/maps?q=36.2,37.1',
        'is_default': true,
        'shipping_text': 'حلب - الفرقان',
      },
    });
    expect(u.isVerified, isTrue);
    expect(u.addressesCount, 2);
    expect(u.defaultAddress!.label, 'work');
    expect(u.defaultAddress!.hasLocation, isTrue);

    final old = AppUser.fromJson({'id': 4, 'name': 'y', 'role': 'customer'});
    expect(old.isVerified, isFalse); // سيرفر أقدم: لا ادعاء توثيق
    expect(old.defaultAddress, isNull);
  });

  testWidgets('profile header shows the real percentage and no fake "verified"',
      (tester) async {
    final auth = AuthProvider()..updateUser(_user());
    await _pump(tester, const ProfileScreen(), auth: auth);

    expect(find.text('%33'), findsOneWidget);
    expect(find.text('%70'), findsNothing);
    expect(find.text('موثّق'), findsNothing);
    expect(find.text('عناويني'), findsOneWidget);
    expect(find.text('أضف عنوان الشحن'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('verified users see the badge; a complete profile hides the nudge',
      (tester) async {
    final auth = AuthProvider()
      ..updateUser(_user(
        phoneVerified: true,
        avatar: 'https://x/a.jpg',
        birthDate: '1990-01-01',
        gender: 'female',
        defaultAddress: _addr(1, isDefault: true),
      ));
    await _pump(tester, const ProfileScreen(), auth: auth);

    expect(find.text('موثّق'), findsOneWidget);
    expect(find.text('أكمل ملفك التعريفي'), findsNothing);
    expect(find.textContaining('%'), findsNothing);
    await _finish(tester);
  });

  testWidgets('adds the first address with "my location" and makes it default',
      (tester) async {
    final fake = _FakeAddresses([]);
    await _pump(
      tester,
      MyAddressesScreen(service: fake, locate: () async => (33.5138, 36.2765)),
      auth: AuthProvider()..updateUser(_user()),
    );

    expect(find.text('لا توجد عناوين محفوظة'), findsOneWidget);
    await tester.pumpAndSettle(); // زر الإضافة يدخل بحركة لا تستقبل اللمس أثناءها
    await tester.tap(find.text('إضافة عنوان'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('العمل'));
    await tester.enterText(find.widgetWithText(TextFormField, 'المدينة'), 'دمشق');
    await tester.enterText(find.widgetWithText(TextFormField, 'العنوان التفصيلي'), 'المزة، بناء 4');
    await tester.tap(find.text('موقعي الحالي'));
    await tester.pump();
    expect(find.text('تم تحديد الموقع على الخريطة.'), findsOneWidget);

    await tester.tap(find.text('حفظ العنوان'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(fake.created, {
      'label': 'work',
      'city': 'دمشق',
      'details': 'المزة، بناء 4',
      'latitude': 33.5138,
      'longitude': 36.2765,
      'is_default': true, // أول عنوان يُعتمد للشحن
    });
    await _finish(tester);
  });

  testWidgets('"my location" fills empty fields from the suggested address only',
      (tester) async {
    final fake = _FakeAddresses([])
      ..suggestion = (city: 'دمشق', details: 'حي الربوة، المزة، نفق الأمويين');
    await _pump(tester, MyAddressesScreen(service: fake, locate: () async => (33.5138, 36.2765)),
        auth: AuthProvider()..updateUser(_user()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة عنوان'));
    await tester.pumpAndSettle();

    // المستخدم كتب المدينة بنفسه: لا نستبدلها
    await tester.enterText(find.widgetWithText(TextFormField, 'المدينة'), 'ريف دمشق');
    await tester.tap(find.text('موقعي الحالي'));
    await tester.pump();
    await tester.pump();

    expect(find.text('ريف دمشق'), findsOneWidget);
    expect(find.text('حي الربوة، المزة، نفق الأمويين، '), findsOneWidget);
    expect(find.text('تم تحديد الموقع وتعبئة المنطقة. راجعها وأكمل رقم البناء والطابق.'), findsOneWidget);
    await _finish(tester);
  });

  testWidgets('the form requires city and details', (tester) async {
    final fake = _FakeAddresses([]);
    await _pump(tester, MyAddressesScreen(service: fake, locate: () async => (0.0, 0.0)),
        auth: AuthProvider()..updateUser(_user()));
    await tester.pumpAndSettle(); // زر الإضافة يدخل بحركة لا تستقبل اللمس أثناءها
    await tester.tap(find.text('إضافة عنوان'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('حفظ العنوان'));
    await tester.pump();

    expect(find.text('المدينة مطلوبة.'), findsOneWidget);
    expect(find.text('اكتب العنوان التفصيلي.'), findsOneWidget);
    expect(fake.created, isNull);
    await _finish(tester);
  });

  testWidgets('three addresses reach the limit', (tester) async {
    final fake = _FakeAddresses([
      _addr(1, isDefault: true),
      _addr(2, label: 'work'),
      _addr(3, label: 'other'),
    ]);
    await _pump(tester, MyAddressesScreen(service: fake, locate: () async => (0.0, 0.0)),
        auth: AuthProvider()..updateUser(_user()));

    expect(find.text('معتمد للشحن'), findsOneWidget);
    expect(find.text('الحد الأقصى 3 عناوين'), findsOneWidget);
    final fab = tester.widget<FloatingActionButton>(find.byType(FloatingActionButton));
    expect(fab.onPressed, isNull);
    await _finish(tester);
  });
}
