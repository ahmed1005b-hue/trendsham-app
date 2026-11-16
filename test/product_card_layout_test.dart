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
      Text renderedText(String key) =>
          tester.widget<Text>(find.descendant(
              of: find.byKey(ValueKey(key)), matching: find.byType(Text)));
      final itemName = renderedText('product-card-name');
      final reviewCount = renderedText('product-card-review-count');
      final price = renderedText('product-card-price');
      final compareAtPrice = renderedText('product-card-compare-price');

      expect(itemName.style!.color, secondaryColor);
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
