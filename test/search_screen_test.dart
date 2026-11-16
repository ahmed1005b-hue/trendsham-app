import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/config/theme.dart';
import 'package:trendsham/l10n/app_localizations.dart';
import 'package:trendsham/models/category.dart' as model;
import 'package:trendsham/models/product.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/providers/auth_provider.dart';
import 'package:trendsham/providers/cart_provider.dart';
import 'package:trendsham/screens/search/search_screen.dart';
import 'package:trendsham/screens/store/store_screen.dart';
import 'package:trendsham/services/product_service.dart';
import 'package:trendsham/theme/theme_switcher.dart';

Product _p(String q, int id) => Product.fromJson({'id': id, 'name': '$q $id', 'slug': 'p$id', 'price': 1000});

/// بحث وهمي: صفحات من 20 منتجاً، ويمكن تأخير ردّ استعلام معيّن.
class _FakeProducts extends ProductService {
  _FakeProducts({this.lastPage = 1});
  final int lastPage;
  final List<(String, int)> calls = [];
  final Map<String, Completer<void>> hold = {};

  @override
  Future<List<String>> trending() async => const [];

  @override
  Future<SearchSuggestions> suggestions(String query) async => const SearchSuggestions(
        products: [],
        categories: [],
        stores: [SuggestionItem(name: 'متجر الياسمين', storeId: 7)],
      );

  @override
  Future<({List<Product> products, int currentPage, int lastPage})> search(String query,
      {String? sort,
      double? minPrice,
      double? maxPrice,
      String? categorySlug,
      int? storeId,
      bool inStock = false,
      bool onSale = false,
      double? minRating,
      int page = 1}) async {
    calls.add((query, page));
    await hold[query]?.future;
    final base = (page - 1) * 20;
    return (
      products: [for (var i = 1; i <= 20; i++) _p(query, base + i)],
      currentPage: page,
      lastPage: lastPage,
    );
  }
}

class _NoCategories extends CategoryService {
  @override
  Future<List<model.Category>> list() async => [];
}

Future<void> _pump(WidgetTester tester, ProductService service, {bool dark = false}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(420, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: AuthProvider()),
      ChangeNotifierProvider.value(value: CartProvider()),
      ChangeNotifierProvider(create: (_) => ThemeController(prefs: prefs)),
      ChangeNotifierProvider(create: (_) => AppSettingsProvider(preferences: prefs)),
    ],
    child: MaterialApp(
      theme: dark ? AppTheme.dark : AppTheme.light,
      locale: const Locale('ar'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: SearchScreen(productService: service, categoryService: _NoCategories()),
    ),
  ));
  await tester.pump(const Duration(milliseconds: 300));
}

Future<void> _submit(WidgetTester tester, String q) async {
  await tester.enterText(find.byType(TextField).first, q);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pump();
  await tester.pump();
}

Future<void> _finish(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 1));
}

/// نسبة التباين وفق WCAG.
double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

void main() {
  for (final dark in [false, true]) {
    testWidgets('typed text is readable in ${dark ? 'dark' : 'light'} mode', (tester) async {
      await _pump(tester, _FakeProducts(), dark: dark);
      final field = tester.widget<TextField>(find.byType(TextField).first);
      final text = field.style!.color!;
      final fill = field.decoration!.fillColor!;
      expect(_contrast(text, fill), greaterThan(7), reason: 'text $text on $fill');
      expect(_contrast(field.decoration!.hintStyle!.color!, fill), greaterThan(4.5));
      await _finish(tester);
    });
  }

  testWidgets('light theme chips have readable labels (selected or not)', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
        body: Wrap(children: [
          const Chip(label: Text('a1')),
          ActionChip(label: const Text('a2'), onPressed: () {}),
          ChoiceChip(label: const Text('a3'), selected: false, onSelected: (_) {}),
          ChoiceChip(label: const Text('a4'), selected: true, onSelected: (_) {}),
          FilterChip(label: const Text('a5'), selected: true, onSelected: (_) {}),
        ]),
      ),
    ));
    final theme = AppTheme.light;
    for (final (label, selected) in [('a1', false), ('a2', false), ('a3', false), ('a4', true), ('a5', true)]) {
      final rp = tester.renderObject<RenderParagraph>(
          find.descendant(of: find.text(label), matching: find.byType(RichText)).first);
      final color = rp.text.style?.color;
      expect(color, isNotNull, reason: '$label has no colour (painted white)');
      final bg = selected
          ? Color.alphaBlend(theme.chipTheme.selectedColor!, Colors.white)
          : theme.chipTheme.backgroundColor!;
      expect(_contrast(color!, bg), greaterThan(7), reason: label);
    }
  });

  testWidgets('scrolling to the end loads the next page', (tester) async {
    final fake = _FakeProducts(lastPage: 3);
    await _pump(tester, fake);
    await _submit(tester, 'عطر');
    expect(fake.calls, [('عطر', 1)]);

    await tester.drag(find.byType(GridView), const Offset(0, -6000));
    await tester.pump();
    await tester.pump();
    expect(fake.calls, [('عطر', 1), ('عطر', 2)]);
    await _finish(tester);
  });

  testWidgets('a slow old search cannot overwrite the newer one', (tester) async {
    final fake = _FakeProducts()..hold['قديم'] = Completer<void>();
    await _pump(tester, fake);
    await _submit(tester, 'قديم');
    await _submit(tester, 'جديد');
    expect(find.text('جديد 1'), findsOneWidget);

    // الرد القديم يصل أخيراً: يُهمل ولا يستبدل نتائج البحث الأحدث
    fake.hold['قديم']!.complete();
    await tester.pump();
    await tester.pump();
    expect(find.text('قديم 1'), findsNothing);
    expect(find.text('جديد 1'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _finish(tester);
  });

  testWidgets('a store suggestion opens the store page', (tester) async {
    await _pump(tester, _FakeProducts());
    await tester.enterText(find.byType(TextField).first, 'ياسمين');
    await tester.pump(const Duration(milliseconds: 400));
    await tester.pump();

    await tester.tap(find.text('متجر الياسمين'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(StoreScreen), findsOneWidget);
    expect(tester.widget<StoreScreen>(find.byType(StoreScreen)).storeId, 7);
    await _finish(tester);
  });
}
