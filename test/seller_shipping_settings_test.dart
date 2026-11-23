import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/screens/seller/seller_shipping_settings_screen.dart';
import 'package:trendsham/services/store_shipping_service.dart';

/// إعدادات شحن المتجر في التطبيق: نفس صفحة الموقع (من يوصل، وأسعار المحافظات، والاستلام، والدين).
class _FakeService extends StoreShippingService {
  _FakeService(this.json);

  final Map<String, dynamic> json;
  StoreShippingSettings? saved;

  @override
  Future<StoreShippingSettings> load() async =>
      StoreShippingSettings.fromJson(json);

  @override
  Future<StoreShippingSettings> save(StoreShippingSettings settings) async {
    saved = settings;
    return settings;
  }
}

Map<String, dynamic> _json({String mode = 'platform', double debt = 0}) => {
      'mode': mode,
      'free_over': null,
      'prep_days': 1,
      'delivery_days': 2,
      'allow_pickup': false,
      'pickup_address': null,
      'rates': [
        {'governorate': 'دمشق', 'label': 'دمشق', 'enabled': false, 'fee': null},
        {'governorate': 'حلب', 'label': 'حلب', 'enabled': false, 'fee': null},
      ],
      'status': {
        'active': false,
        'reason': null,
        'debt': debt,
        'limit': 100000,
      },
    };

Future<void> _open(WidgetTester tester, _FakeService service) async {
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SellerShippingSettingsScreen(service: service),
  ));
  await tester.pumpAndSettle();
}

void main() {
  test('settings are sent in the same shape as the website form', () {
    final s = StoreShippingSettings.fromJson(_json(mode: 'self'));
    s.rates.first
      ..enabled = true
      ..fee = 5000;
    s.allowPickup = true;
    s.pickupAddress = 'دمشق - الحمرا';

    final body = s.toJson();
    expect(body['mode'], 'self');
    expect(body['rates'], {
      'دمشق': {'enabled': true, 'fee': 5000.0},
    });
    expect(body['pickup_address'], 'دمشق - الحمرا');
  });

  testWidgets('seller switches to own delivery, prices a governorate and saves',
      (tester) async {
    final service = _FakeService(_json());
    await _open(tester, service);

    expect(find.byKey(const ValueKey('shipping-rate-دمشق')), findsNothing);

    await tester.tap(find.byKey(const ValueKey('shipping-mode-self')));
    await tester.pumpAndSettle();
    final damascus = find.byKey(const ValueKey('shipping-rate-دمشق'));
    expect(damascus, findsOneWidget);

    await tester
        .tap(find.descendant(of: damascus, matching: find.byType(Checkbox)));
    await tester.pump();
    await tester.enterText(
        find.descendant(of: damascus, matching: find.byType(TextField)),
        '7000');

    final save = find.byKey(const ValueKey('shipping-save'));
    await tester.scrollUntilVisible(save, 300,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(save);
    await tester.pumpAndSettle();

    expect(service.saved, isNotNull);
    expect(service.saved!.mode, 'self');
    expect(service.saved!.toJson()['rates'], {
      'دمشق': {'enabled': true, 'fee': 7000.0},
    });
  });

  testWidgets('the store debt is shown when the wallet is negative',
      (tester) async {
    await _open(tester, _FakeService(_json(mode: 'self', debt: 25000)));

    expect(find.byKey(const ValueKey('shipping-debt')), findsOneWidget);
    expect(find.textContaining('25,000'), findsOneWidget);
  });
}
