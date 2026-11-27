import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/category.dart';
import 'package:trendsham/models/coupon_story.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/services/product_service.dart';
import 'package:trendsham/services/showcase_service.dart';
import 'package:trendsham/widgets/showcase_section.dart';
import 'package:trendsham/screens/category/category_products_screen.dart';
import 'package:trendsham/screens/home/home_tab.dart';
import 'package:trendsham/theme/theme_switcher.dart';
import 'package:trendsham/services/recently_viewed_store.dart';
import 'package:trendsham/widgets/brand_wordmark.dart';

class _FakeProductService extends ProductService {
  String? lastSearchQuery;
  bool? lastSearchOnSale;

  Product get _saleProduct => Product(
        id: 1,
        slug: 'linen-shirt',
        name: 'قميص كتان',
        price: 25000,
        compareAtPrice: 30000,
        discountPercentage: 17,
        stockQuantity: 4,
        inStock: true,
        reviewsCount: 0,
      );

  @override
  Future<List<Product>> list({
    String? categorySlug,
    String? sort,
    double? minPrice,
    double? maxPrice,
    int page = 1,
  }) async =>
      [_saleProduct];

  @override
  Future<({List<Product> newArrivals, List<Product> deals})>
      homeSections() async => (
            newArrivals: [
              _saleProduct,
              Product(
                id: 2,
                slug: 'other-store-lamp',
                name: 'مصباح متجر آخر',
                price: 18000,
                stockQuantity: 2,
                inStock: true,
                reviewsCount: 0,
              ),
            ],
            deals: [_saleProduct],
          );

  @override
  Future<List<Product>> dailyDeals() async => [_saleProduct];

  @override
  Future<List<Product>> byIds(List<int> ids) async =>
      ids.contains(1) ? [_saleProduct] : [];

  @override
  Future<({List<Product> products, int currentPage, int lastPage})> search(
    String query, {
    String? sort,
    double? minPrice,
    double? maxPrice,
    String? categorySlug,
    int? storeId,
    bool inStock = false,
    bool onSale = false,
    double? minRating,
    int page = 1,
  }) async {
    lastSearchQuery = query;
    lastSearchOnSale = onSale;
    return (products: [_saleProduct], currentPage: 1, lastPage: 1);
  }
}

class _FakeCategoryService extends CategoryService {
  final category = Category(
    id: 7,
    slug: 'fashion',
    name: 'الأزياء',
  );

  @override
  Future<List<Category>> list() async => [category];

  @override
  Future<List<Product>> products(
    String slug, {
    String? sort,
    double? minPrice,
    double? maxPrice,
  }) async =>
      [];
}

class _FakeShowcaseService extends ShowcaseService {
  _FakeShowcaseService([this.showcases = const []]);

  final List<ShowcaseData> showcases;
  final events = <String>[];

  @override
  Future<List<ShowcaseData>> homeShowcases() async => showcases;

  @override
  Future<void> track(int showcaseId, String type) async =>
      events.add('$showcaseId:$type');
}

class _FakeStoryService extends StoryService {
  @override
  Future<List<StoryModel>> getActiveStories() async => [];
}

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = true;
  });

  double contrastRatio(Color foreground, Color background) {
    final luminance = [
      foreground.computeLuminance(),
      background.computeLuminance()
    ]..sort();
    return (luminance[1] + 0.05) / (luminance[0] + 0.05);
  }

  Future<void> pumpHome(
    WidgetTester tester,
    CategoryService categories, {
    ProductService? products,
    Size viewport = const Size(360, 800),
    ThemeData? theme,
    ShowcaseService? showcases,
    Map<String, Object> prefsValues = const {},
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    SharedPreferences.setMockInitialValues(prefsValues);
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => ThemeController(prefs: prefs),
        child: MaterialApp(
          theme: theme,
          locale: const Locale('ar'),
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: HomeTab(
            productService: products ?? _FakeProductService(),
            categoryService: categories,
            storyService: _FakeStoryService(),
            showcaseService: showcases ?? _FakeShowcaseService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('home loads live categories and opens the selected category',
      (tester) async {
    final categories = _FakeCategoryService();
    await pumpHome(tester, categories);

    expect(find.text('الأزياء'), findsOneWidget);
    await tester.tap(find.text('الأزياء'));
    await tester.pumpAndSettle();

    expect(find.byType(CategoryProductsScreen), findsOneWidget);
    expect(find.text('الأزياء'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('recently viewed products show on home and can be cleared',
      (tester) async {
    await pumpHome(tester, _FakeCategoryService(), prefsValues: {
      'trendsham_recently_viewed': ['1', '99'],
    });

    expect(find.text('شاهدته مؤخراً'), findsOneWidget);
    await tester.ensureVisible(find.text('مسح السجل'));
    await tester.tap(find.text('مسح السجل'));
    await tester.pumpAndSettle();

    expect(find.text('شاهدته مؤخراً'), findsNothing);
    expect(await RecentlyViewedStore.ids(), isEmpty);
  });

  testWidgets('no recently viewed section without history', (tester) async {
    await pumpHome(tester, _FakeCategoryService());
    expect(find.text('شاهدته مؤخراً'), findsNothing);
  });

  testWidgets('home renders offer prices and newest products from API data',
      (tester) async {
    await pumpHome(tester, _FakeCategoryService());

    expect(find.textContaining('25000'), findsWidgets);
    expect(find.bySemanticsLabel('تريندشام'), findsOneWidget);
    expect(find.byType(BrandWordmark),
        findsOneWidget); // الشعار نصي كالويب (لا صورة)
    final spotlightLabel = tester.widget<Text>(find.text('تخفيضات مختارة'));
    expect(
      contrastRatio(spotlightLabel.style!.color!, AppColors.gold),
      greaterThanOrEqualTo(4.5),
    );

    final context = tester.element(find.byType(HomeTab));
    await tester.ensureVisible(find.text('تصفّح الكل'));
    await tester.pumpAndSettle();
    final resultAction = find.ancestor(
        of: find.text('تصفّح الكل'), matching: find.byType(TextButton));
    final resultButton = tester.widget<TextButton>(resultAction);
    final resultColor =
        resultButton.style!.foregroundColor!.resolve(<WidgetState>{})!;
    expect(
      contrastRatio(AppColors.brandGreen, AppColors.bgLight),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      contrastRatio(resultColor, Theme.of(context).scaffoldBackgroundColor),
      greaterThanOrEqualTo(4.5),
    );
    final buttonStyle = AppTheme.light.elevatedButtonTheme.style!;
    expect(
      contrastRatio(
        buttonStyle.foregroundColor!.resolve({})!,
        buttonStyle.backgroundColor!.resolve({})!,
      ),
      greaterThanOrEqualTo(4.5),
    );
    expect(find.text('أحدث المنتجات'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('newest products come from the home sections like the website',
      (tester) async {
    await pumpHome(tester, _FakeCategoryService());

    await tester.scrollUntilVisible(
      find.text('مصباح متجر آخر'),
      300,
      scrollable: find
          .descendant(
              of: find.byType(CustomScrollView),
              matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('مصباح متجر آخر'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('app bar foregrounds meet contrast against the app bar surface', () {
    for (final theme in [AppTheme.light, AppTheme.dark]) {
      final appBar = theme.appBarTheme;
      final background = appBar.backgroundColor!;
      final foreground = appBar.foregroundColor!;

      expect(contrastRatio(foreground, background), greaterThanOrEqualTo(4.5));
      expect(
        contrastRatio(appBar.titleTextStyle!.color!, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(appBar.iconTheme!.color!, background),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        contrastRatio(appBar.actionsIconTheme!.color!, background),
        greaterThanOrEqualTo(4.5),
      );
    }
  });

  testWidgets('home fits a narrow phone viewport without overflow',
      (tester) async {
    await pumpHome(
      tester,
      _FakeCategoryService(),
      viewport: const Size(320, 720),
    );

    // الأقسام فقاعات كما في الويب، بلا عنوان "تصفّح الأقسام"
    expect(find.text('تصفّح الأقسام'), findsNothing);
    expect(find.byType(ActionChip), findsNothing);
    expect(find.bySemanticsLabel('الأزياء'), findsOneWidget);
    // لا أيقونة مطابقة لاسم "الأزياء" => يظهر أول حرف داخل القرص (مثل الويب)
    expect(find.text('ا'), findsOneWidget);
    expect(find.text('قميص كتان'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('home brand logo and deal link remain legible in dark mode',
      (tester) async {
    await pumpHome(
      tester,
      _FakeCategoryService(),
      theme: ThemeData.dark(),
    );

    final context = tester.element(find.byType(HomeTab));
    expect(find.bySemanticsLabel('تريندشام'), findsOneWidget);
    await tester.ensureVisible(find.text('تصفّح الكل'));
    await tester.pumpAndSettle();
    final resultAction = find.ancestor(
      of: find.text('تصفّح الكل'),
      matching: find.byType(TextButton),
    );
    final resultButton = tester.widget<TextButton>(resultAction);
    final resultColor =
        resultButton.style!.foregroundColor!.resolve(<WidgetState>{})!;
    final background = Theme.of(context).scaffoldBackgroundColor;

    expect(
      contrastRatio(resultColor, background),
      greaterThanOrEqualTo(4.5),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('home renders rented showcases and tracks their events',
      (tester) async {
    final showcases = _FakeShowcaseService([
      ShowcaseData.fromJson({
        'id': 9,
        'placement': 'home_top',
        'title': 'متجر النخبة',
        'subtitle': 'أفضل العروض',
        'sponsored_label': 'إعلان',
        'gradient': {
          'colors': ['#0F3D2E', '#2E7D5B'],
          'direction': 'diagonal',
        },
        'text_color': 'light',
        'store': {'id': 4, 'name': 'النخبة', 'logo_url': null},
        'products': [
          {
            'id': 1,
            'slug': 'linen-shirt',
            'name': 'قميص العرض',
            'price': 25000,
            'old_price': 30000,
            'image_url': null,
          },
        ],
      }),
    ]);
    await pumpHome(tester, _FakeCategoryService(), showcases: showcases);

    await tester.ensureVisible(find.text('متجر النخبة'));
    await tester.pumpAndSettle();
    expect(find.text('قميص العرض'), findsOneWidget);
    expect(showcases.events, contains('9:impression'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('deals action opens results with the sale filter applied',
      (tester) async {
    final products = _FakeProductService();
    await pumpHome(
      tester,
      _FakeCategoryService(),
      products: products,
    );

    await tester.ensureVisible(find.text('كل المنتجات'));
    await tester.tap(find.text('كل المنتجات'));
    await tester.pumpAndSettle();

    expect(products.lastSearchQuery, isEmpty);
    expect(products.lastSearchOnSale, isTrue);
    expect(find.text('قميص كتان'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
