import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/product_options.dart';
import 'package:trendsham/screens/seller/product_options_controller.dart';
import 'package:trendsham/screens/seller/product_options_editor.dart';

const _red = ColorOption(name: 'أحمر', label: 'أحمر', hex: '#D32F2F');
const _black = ColorOption(name: 'أسود', label: 'أسود', hex: '#1A1A1A');

const _catalog = ProductOptionsCatalog(
  colors: [_red, _black],
  sizeSystems: [
    SizeSystem(
      key: 'letters',
      label: 'أحرف (ملابس)',
      sizes: ['XS', 'S', 'M', 'L', 'XL', 'XXL', 'XXXL', '4XL'],
    ),
  ],
);

/// شاشة هاتف ضيقة (360 بكسل) حتى يظهر أي تجاوز للعرض كخطأ في الاختبار.
Future<void> _pumpEditor(
  WidgetTester tester,
  ProductOptionsController controller, {
  Locale locale = const Locale('ar'),
}) async {
  tester.view.physicalSize = const Size(360, 2600);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MaterialApp(
    locale: locale,
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: ProductOptionsEditor(controller: controller),
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('seller picks a color and a size, then fills the stock',
      (tester) async {
    final controller = ProductOptionsController(_catalog);
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    await tester.tap(find.text('هذا المنتج له ألوان أو مقاسات'));
    await tester.pumpAndSettle();
    expect(controller.enabled, isTrue);

    await tester.tap(find.text('أحمر'));
    await tester.pump();
    expect(controller.isPaletteSelected(_red), isTrue);

    await tester.tap(find.widgetWithText(FilterChip, 'M'));
    await tester.pump();
    expect(controller.sizes, ['M']);

    await tester.enterText(
        find.byKey(const ValueKey('options-stock:#D32F2F|M')), '5');
    await tester.pump();
    expect(controller.totalStock, 5);
    expect(find.text('المجموع: 5 قطعة في 1 خيار'), findsOneWidget);

    await tester.enterText(
        find.widgetWithText(TextField, 'الكمية لكل الخيارات'), '3');
    await tester.tap(find.text('تطبيق').first);
    await tester.pump();
    expect(controller.combo('#D32F2F', 'M').stock, '3');
    expect(
      tester
          .widget<TextField>(
              find.byKey(const ValueKey('options-stock:#D32F2F|M')))
          .controller!
          .text,
      '3',
    );
    expect(find.text('المجموع: 3 قطعة في 1 خيار'), findsOneWidget);
  });

  testWidgets('a second dot in the price keeps what the seller typed',
      (tester) async {
    final controller = ProductOptionsController(_catalog)
      ..setEnabled(true)
      ..togglePaletteColor(_red)
      ..toggleSize('M');
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    final price = find.byKey(const ValueKey('options-price:#D32F2F|M'));
    await tester.enterText(price, '1.2');
    await tester.pump();
    await tester.enterText(price, '1.2.');
    await tester.pump();
    expect(tester.widget<TextField>(price).controller!.text, '1.2');
    await tester.enterText(price, '1.2x');
    await tester.pump();
    expect(tester.widget<TextField>(price).controller!.text, '1.2');
    expect(controller.combo('#D32F2F', 'M').priceIncrease, '1.2');
  });

  testWidgets('turning a combination off updates the totals', (tester) async {
    final controller = ProductOptionsController(_catalog)
      ..setEnabled(true)
      ..togglePaletteColor(_red)
      ..togglePaletteColor(_black)
      ..toggleSize('M')
      ..setAllStock('2');
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    expect(find.text('المجموع: 4 قطعة في 2 خيار'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('options-available:#1A1A1A|M')));
    await tester.pump();
    expect(controller.combo('#1A1A1A', 'M').available, isFalse);
    expect(find.text('المجموع: 2 قطعة في 1 خيار'), findsOneWidget);
  });

  testWidgets('other color dialog adds a custom color', (tester) async {
    final controller = ProductOptionsController(_catalog)..setEnabled(true);
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    await tester.tap(find.text('لون آخر'));
    await tester.pumpAndSettle();
    expect(find.text('درجة اللون'), findsOneWidget);
    expect(find.text('التشبع'), findsOneWidget);
    expect(find.text('السطوع'), findsOneWidget);

    await tester.tap(find.text('إضافة'));
    await tester.pump();
    expect(find.text('اكتب اسم اللون.'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, 'اسم اللون'), 'نيلي');
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(controller.colors, hasLength(1));
    expect(controller.colors.single.name, 'نيلي');
    expect(isHexColor(controller.colors.single.hex), isTrue);
    expect(find.text('نيلي'), findsWidgets);
  });

  testWidgets('a legacy word color gets a shade from the dialog',
      (tester) async {
    final controller = ProductOptionsController(_catalog)
      ..load([
        const ProductVariant(
          id: 9,
          color: 'زهري فاتح',
          colorName: 'زهري فاتح',
          size: 'M',
          stockQuantity: 4,
          priceAdjustment: 0,
        ),
      ]);
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller);

    expect(controller.colors.single.hex, isNull);
    await tester.tap(find.byTooltip('لون مكتوب سابقاً — اضغط لاختيار درجته'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('إضافة'));
    await tester.pumpAndSettle();

    expect(controller.colors.single.key, 'زهري فاتح');
    expect(isHexColor(controller.colors.single.hex), isTrue);
  });

  testWidgets('English layout fits a 360 px phone with SKU shown',
      (tester) async {
    final controller = ProductOptionsController(_catalog)
      ..setEnabled(true)
      ..togglePaletteColor(_red)
      ..togglePaletteColor(_black)
      ..toggleSize('S')
      ..toggleSize('M')
      ..toggleSize('XXXL');
    addTearDown(controller.dispose);
    await _pumpEditor(tester, controller, locale: const Locale('en'));

    await tester.tap(find.text('Show an SKU code for each option'));
    await tester.pumpAndSettle();

    expect(find.text('Colors'), findsOneWidget);
    expect(find.text('Stock and prices'), findsOneWidget);
    expect(find.text('Total: 0 items in 6 options'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'SKU code'), findsNWidgets(6));
    expect(tester.takeException(), isNull);
  });
}
