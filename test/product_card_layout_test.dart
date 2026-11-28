import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/vendor.dart';
import 'package:trendsham/widgets/product_card.dart';

void main() {
  double contrastRatio(Color foreground, Color background) {
    final luminance = [
      foreground.computeLuminance(),
      background.computeLuminance(),
    ]..sort();
    return (luminance[1] + 0.05) / (luminance[0] + 0.05);
  }

  testWidgets('product card fits in a narrow category grid tile',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final product = Product(
      id: 1,
      slug: 'menswear',
      name: '11',
      price: 125,
      compareAtPrice: 150,
      discountPercentage: 20,
      stockQuantity: 1,
      inStock: true,
      reviewsCount: 32,
      vendor: Vendor(id: 1, storeName: 'Trend Sham'),
    );

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('tr'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(
        body: GridView(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            ProductCard(product: product, onTap: () {}),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  Future<void> pumpCard(WidgetTester tester, Product product,
      {VoidCallback? onAdd}) async {
    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 170,
          height: 280,
          child: ProductCard(
            product: product,
            onTap: () {},
            onAddToCart: onAdd == null
                ? null
                : (_, __, {specialPrice, discountPercentage}) => onAdd(),
          ),
        ),
      ),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'every card shows its whole content and images line up in a grid row',
      (tester) async {
    for (final width in [320.0, 360.0]) {
      tester.view.physicalSize = Size(width, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final short = Product(
        id: 11,
        slug: 'short',
        name: 'قلم',
        price: 90,
        stockQuantity: 3,
        inStock: true,
        reviewsCount: 0,
        vendor: Vendor(id: 1, storeName: 'متجر'),
      );
      final long = Product(
        id: 12,
        slug: 'long',
        name: 'حذاء جلد طبيعي إصدار محدود بتصميم كلاسيكي للمناسبات',
        price: 150000,
        compareAtPrice: 180000,
        discountPercentage: 17,
        stockQuantity: 3,
        inStock: true,
        reviewsCount: 12,
        averageRating: 4.5,
        vendor: Vendor(id: 2, storeName: 'متجر خليل للتجارة العامة'),
      );

      await tester.pumpWidget(MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: GridView(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.66, // أضيق شبكة: الرئيسية
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            children: [
              for (final product in [short, long])
                ProductCard(
                  key: ValueKey('card-${product.id}'),
                  product: product,
                  onTap: () {},
                  onAddToCart: (_, __, {specialPrice, discountPercentage}) {},
                ),
            ],
          ),
        ),
      ));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'width $width');

      double imageHeight(int id) => tester
          .getSize(find
              .descendant(
                  of: find.byKey(ValueKey('card-$id')),
                  matching: find.byType(ClipRRect))
              .first)
          .height;
      expect(imageHeight(11), imageHeight(12), reason: 'width $width');

      for (final id in [11, 12]) {
        final card = find.byKey(ValueKey('card-$id'));
        final shell = tester.getRect(find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('product-card-shell'))));
        final button = tester.getRect(find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('product-card-add-to-cart'))));
        final price = tester.getRect(find.descendant(
            of: card,
            matching: find.byKey(const ValueKey('product-card-price'))));
        expect(
            shell.contains(button.bottomLeft) &&
                shell.contains(button.topRight),
            isTrue,
            reason: 'card $id at width $width: the + button is cut off');
        expect(price.bottom <= shell.bottom, isTrue,
            reason: 'card $id at width $width: the price is cut off');
      }
    }
  });

  testWidgets('a discounted card shows the discount on the image corner',
      (tester) async {
    await pumpCard(
      tester,
      Product(
        id: 5,
        slug: 'sale',
        name: 'منتج بخصم',
        price: 80,
        compareAtPrice: 100,
        discountPercentage: 20,
        stockQuantity: 3,
        inStock: true,
        reviewsCount: 0,
        isNew: true,
      ),
    );

    expect(
        find.descendant(
            of: find.byKey(const ValueKey('product-card-badge')),
            matching: find.text('-20%')),
        findsOneWidget);
    expect(find.text('جديد'), findsNothing); // الخصم أولى من «جديد»
    expect(tester.takeException(), isNull);
  });

  testWidgets('a new card without a discount shows the New badge',
      (tester) async {
    await pumpCard(
      tester,
      Product(
        id: 6,
        slug: 'fresh',
        name: 'منتج جديد',
        price: 90,
        stockQuantity: 3,
        inStock: true,
        reviewsCount: 0,
        isNew: true,
      ),
    );

    expect(find.byKey(const ValueKey('product-card-badge')), findsOneWidget);
    expect(find.text('جديد'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the plus button beside the price adds the product to the cart',
      (tester) async {
    var added = 0;
    await pumpCard(
      tester,
      Product(
        id: 7,
        slug: 'plain',
        name: 'منتج عادي',
        price: 90,
        stockQuantity: 3,
        inStock: true,
        reviewsCount: 0,
      ),
      onAdd: () => added++,
    );

    expect(find.byKey(const ValueKey('product-card-badge')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('product-card-add-to-cart')));
    expect(added, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('store product card exposes Q&A and comparison actions',
      (tester) async {
    final product = Product(
      id: 2,
      slug: 'store-item',
      name: 'منتج المتجر',
      price: 250,
      stockQuantity: 4,
      inStock: true,
      reviewsCount: 0,
    );
    var questionsOpened = false;
    var compared = false;

    await tester.pumpWidget(MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: GridView(
          padding: const EdgeInsets.all(12),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 0.68,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          children: [
            ProductCard(
              product: product,
              onTap: () {},
              onQuestionsTap: () => questionsOpened = true,
              onCompareTap: () => compared = true,
            ),
          ],
        ),
      ),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('أسئلة وأجوبة المنتج'));
    await tester.tap(find.byIcon(Icons.compare_arrows));
    expect(questionsOpened, isTrue);
    expect(compared, isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('product card border and image fallback use dark theme colors',
      (tester) async {
    final product = Product(
      id: 3,
      slug: 'dark-mode-item',
      name: 'منتج الوضع الداكن',
      price: 180,
      stockQuantity: 2,
      inStock: true,
      reviewsCount: 0,
    );

    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SizedBox(
          width: 170,
          height: 280,
          child: ProductCard(product: product, onTap: () {}),
        ),
      ),
    ));
    await tester.pumpAndSettle();

    final context = tester.element(find.byType(ProductCard));
    final shell = tester
        .widget<Container>(find.byKey(const ValueKey('product-card-shell')));
    final placeholder = tester.widget<ColoredBox>(
        find.byKey(const ValueKey('product-image-placeholder')));
    final decoration = shell.decoration! as BoxDecoration;
    final placeholderIcon = tester.widget<Icon>(
      find.byIcon(Icons.image_not_supported_outlined),
    );

    expect(decoration.border!.top.color,
        Theme.of(context).colorScheme.outlineVariant);
    expect(placeholder.color,
        Theme.of(context).colorScheme.surfaceContainerHighest);
    expect(
      placeholderIcon.color,
      Theme.of(context).colorScheme.onSurfaceVariant,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'product card secondary and price text meet contrast in both themes',
      (tester) async {
    final product = Product(
      id: 4,
      slug: 'contrast-item',
      name: 'Contrast Item',
      price: 125,
      compareAtPrice: 150,
      stockQuantity: 2,
      inStock: true,
      reviewsCount: 5,
      averageRating: 4.5,
    );

    for (final theme in [AppTheme.light, AppTheme.dark]) {
      await tester.pumpWidget(MaterialApp(
        theme: theme,
        locale: const Locale('en'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SizedBox(
            width: 170,
            height: 280,
            child: ProductCard(product: product, onTap: () {}),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      final context = tester.element(find.byType(ProductCard));
      final colorScheme = Theme.of(context).colorScheme;
      final background = colorScheme.surface;
      final secondaryColor = colorScheme.onSurfaceVariant;
      final priceColor = Theme.of(context).brightness == Brightness.light
          ? AppColors.brandGreen
          : AppColors.gold;
      Text renderedText(String key) => tester.widget<Text>(find.descendant(
          of: find.byKey(ValueKey(key)), matching: find.byType(Text)));
      final itemName = renderedText('product-card-name');
      final reviewCount = renderedText('product-card-review-count');
      final price = renderedText('product-card-price');
      final compareAtPrice = renderedText('product-card-compare-price');

      expect(itemName.style!.color, colorScheme.onSurface);
      expect(contrastRatio(colorScheme.onSurface, background),
          greaterThanOrEqualTo(4.5));
      expect(reviewCount.style!.color, secondaryColor);
      expect(compareAtPrice.style!.color, secondaryColor);
      expect(price.style!.color, priceColor);
      expect(
          contrastRatio(secondaryColor, background), greaterThanOrEqualTo(4.5));
      expect(contrastRatio(priceColor, background), greaterThanOrEqualTo(4.5));
      expect(tester.takeException(), isNull);
    }
  });
}
