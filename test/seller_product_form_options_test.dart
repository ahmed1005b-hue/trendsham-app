import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/category.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/product_options.dart';
import 'package:trendsham/models/vendor.dart';
import 'package:trendsham/screens/seller/seller_product_form_screen.dart';
import 'package:trendsham/services/product_service.dart';
import 'package:trendsham/services/seller_service.dart';

const _catalog = ProductOptionsCatalog(
  colors: [
    ColorOption(name: 'أسود', label: 'Black', hex: '#1A1A1A'),
    ColorOption(name: 'أحمر', label: 'Red', hex: '#D32F2F'),
  ],
  sizeSystems: [
    SizeSystem(key: 'letters', label: 'Letters', sizes: ['S', 'M', 'L']),
  ],
);

class _FakeSellerService extends SellerService {
  _FakeSellerService({this.failOptions = false});

  final bool failOptions;
  Map<String, String>? updatedFields;
  int updateCalls = 0;

  @override
  Future<List<Category>> categories() async => [
        Category(id: 1, name: 'ملابس', slug: 'clothes'),
      ];

  @override
  Future<ProductOptionsCatalog> productOptions() async {
    if (failOptions) {
      throw Exception('offline');
    }
    return _catalog;
  }

  @override
  Future<void> updateProduct(
    int id, {
    required Map<String, String> fields,
    List<XFile>? images,
  }) async {
    updateCalls++;
    updatedFields = fields;
  }
}

class _FakeProductService extends ProductService {
  _FakeProductService(this.product);

  final Product product;

  @override
  Future<Product> show(String slug) async => product;
}

Product _legacyProduct() {
  return Product(
    id: 7,
    slug: 'shirt',
    name: 'قميص',
    price: 1000,
    stockQuantity: 4,
    inStock: true,
    reviewsCount: 0,
    category: Category(id: 1, name: 'ملابس', slug: 'clothes'),
    images: [
      ProductImage(
          id: 11,
          url: 'https://example.test/a.jpg',
          isPrimary: true,
          color: 'اسود',
          colorName: 'اسود'),
    ],
    variants: const [
      ProductVariant(
        id: 1,
        color: 'اسود',
        colorName: 'اسود',
        size: 'M',
        stockQuantity: 4,
        priceAdjustment: 15,
      ),
    ],
  );
}

Future<void> _pump(
  WidgetTester tester,
  _FakeSellerService seller,
  Product product, {
  Product? listProduct,
}) async {
  tester.view.physicalSize = const Size(400, 4000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    locale: const Locale('ar'),
    supportedLocales: AppLocalizations.supportedLocales,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: SellerProductFormScreen(
      product: listProduct ?? product,
      sellerService: seller,
      productService: _FakeProductService(product),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _save(WidgetTester tester) async {
  final button = find.text('حفظ التعديلات');
  await tester.ensureVisible(button);
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'editing a legacy product sends the palette color with its original key',
      (tester) async {
    final seller = _FakeSellerService();
    await _pump(tester, seller, _legacyProduct());

    expect(
      tester
          .widget<SwitchListTile>(find.widgetWithText(
              SwitchListTile, 'هذا المنتج له ألوان أو مقاسات'))
          .value,
      isTrue,
    );

    await _save(tester);

    final f = seller.updatedFields!;
    expect(f['variant_color[0]'], '#1A1A1A');
    expect(f['variant_original_color[0]'], 'اسود');
    expect(f['variant_stock_quantity[0]'], '4');
    expect(f['variant_price_adjustment[0]'], '15');
    expect(f['stock_quantity'], '4');
    expect(f['replace_variants'], '1');
    expect(f['existing_image_color[11]'], '#1A1A1A');
    expect(f['existing_image_color_name[11]'], 'أسود');
  });

  testWidgets('stock field is read-only while options are on', (tester) async {
    await _pump(tester, _FakeSellerService(), _legacyProduct());

    final stock = find.widgetWithText(TextField, 'الكمية بالمخزون');
    expect(tester.widget<TextField>(stock).readOnly, isTrue);
    expect(find.text('يُحسب تلقائياً من الألوان والمقاسات'), findsOneWidget);
  });

  testWidgets(
      'saving with every combination unavailable shows the message and does not call updateProduct',
      (tester) async {
    final seller = _FakeSellerService();
    await _pump(tester, seller, _legacyProduct());

    final toggle = find.byKey(const ValueKey('options-available:#1A1A1A|M'));
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await _save(tester);

    expect(
        find.text('فعّل خياراً واحداً على الأقل، أو أوقف الألوان والمقاسات.'),
        findsOneWidget);
    expect(seller.updateCalls, 0);
  });

  testWidgets('a failed options load never sends variants or replace_variants',
      (tester) async {
    final seller = _FakeSellerService(failOptions: true);
    await _pump(tester, seller, _legacyProduct());

    expect(find.text('تعذّر تحميل الألوان والمقاسات.'), findsOneWidget);
    final stock = find.widgetWithText(TextField, 'الكمية بالمخزون');
    expect(tester.widget<TextField>(stock).readOnly, isFalse);

    await _save(tester);

    final f = seller.updatedFields!;
    expect(f.containsKey('replace_variants'), isFalse);
    expect(f.keys.where((k) => k.startsWith('variant_')), isEmpty);
    expect(f['stock_quantity'], '4');
  });

  testWidgets(
      'switching options off warns using the fetched variants and clears image colors',
      (tester) async {
    final seller = _FakeSellerService();
    final full = _legacyProduct();
    final listOnly = Product(
      id: 7,
      slug: 'shirt',
      name: 'قميص',
      price: 1000,
      stockQuantity: 4,
      inStock: true,
      reviewsCount: 0,
      category: full.category,
    );
    await _pump(tester, seller, full, listProduct: listOnly);

    final toggle =
        find.widgetWithText(SwitchListTile, 'هذا المنتج له ألوان أو مقاسات');
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    await _save(tester);

    expect(find.text('سيتم حذف كل الألوان والمقاسات عند الحفظ. متابعة؟'),
        findsOneWidget);
    expect(seller.updateCalls, 0);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();

    final f = seller.updatedFields!;
    expect(f['replace_variants'], '1');
    expect(f.keys.where((k) => k.startsWith('variant_[')), isEmpty);
    expect(f['existing_image_color[11]'], '');
    expect(f['existing_image_color_name[11]'], '');
    expect(f.keys.where((k) => k.startsWith('image_color')), isEmpty);
  });

  testWidgets('typing combo stock updates the stock field and submitted total',
      (tester) async {
    final seller = _FakeSellerService();
    await _pump(tester, seller, _legacyProduct());

    final field = find.byKey(const ValueKey('options-stock:#1A1A1A|M'));
    await tester.ensureVisible(field);
    await tester.enterText(field, '9');
    await tester.pumpAndSettle();

    final stock = find.widgetWithText(TextField, 'الكمية بالمخزون');
    expect(tester.widget<TextField>(stock).controller!.text, '9');
    await _save(tester);
    expect(seller.updatedFields!['stock_quantity'], '9');
    expect(seller.updatedFields!['variant_stock_quantity[0]'], '9');
  });

  testWidgets('dropped legacy options need confirmation; cancel does not save',
      (tester) async {
    final seller = _FakeSellerService();
    final base = _legacyProduct();
    final product = Product(
      id: 7,
      slug: 'shirt',
      name: 'قميص',
      price: 1000,
      stockQuantity: 6,
      inStock: true,
      reviewsCount: 0,
      category: base.category,
      variants: const [
        ProductVariant(id: 1, size: 'M', stockQuantity: 2),
        ProductVariant(
            id: 2,
            color: 'اسود',
            colorName: 'اسود',
            size: 'M',
            stockQuantity: 4),
      ],
    );
    await _pump(tester, seller, product);
    await _save(tester);

    expect(
        find.text(
            'سيتم حذف 1 من الخيارات القديمة التي لا تناسب الجدول عند الحفظ. متابعة؟'),
        findsOneWidget);
    await tester.tap(find.text('إلغاء'));
    await tester.pumpAndSettle();
    expect(seller.updateCalls, 0);

    await _save(tester);
    await tester.tap(find.text('متابعة'));
    await tester.pumpAndSettle();
    expect(seller.updateCalls, 1);
  });
}
