import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/widgets/showcase_section.dart';

Map<String, dynamic> _product(Map<String, dynamic> extra) => {
      'id': 7,
      'slug': 'p',
      'name': 'منتج',
      'price': 100,
      'image_url': 'https://cdn.test/storage/products/main.jpg',
      ...extra,
    };

void main() {
  test('reads up to five card images from the API', () {
    final p = ShowcaseProduct.fromJson(_product({
      'images': List.generate(7, (i) => 'https://cdn.test/storage/thumbs/p$i.webp'),
    }));
    expect(p.images, hasLength(5));
    expect(p.images.first, endsWith('thumbs/p0.webp'));
  });

  test('older servers without `images` fall back to the main image', () {
    final p = ShowcaseProduct.fromJson(_product({}));
    expect(p.images, ['https://cdn.test/storage/products/main.jpg']);

    final none = ShowcaseProduct.fromJson(_product({'image_url': null, 'images': []}));
    expect(none.images, isEmpty);
  });

  Future<PageController> pumpImages(WidgetTester tester, {bool reduceMotion = false}) async {
    await tester.pumpWidget(MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduceMotion),
        child: const Center(
          child: SizedBox(
            width: 150,
            height: 150,
            child: ShowcaseCardImages(urls: ['https://a/1.webp', 'https://a/2.webp', 'https://a/3.webp']),
          ),
        ),
      ),
    ));
    await tester.pump();
    return tester.widget<PageView>(find.byType(PageView)).controller!;
  }

  testWidgets('card images rotate automatically like the web card', (tester) async {
    final controller = await pumpImages(tester);
    expect(controller.page, 0);

    await tester.pump(ShowcaseCardImages.interval);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.page, 1);

    await tester.pump(ShowcaseCardImages.interval);
    await tester.pump(const Duration(milliseconds: 400));
    expect(controller.page, 2);

    // يُلغى المؤقت عند إزالة البطاقة (لا مؤقتات معلّقة)
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('respects the device "reduce motion" setting', (tester) async {
    final controller = await pumpImages(tester, reduceMotion: true);
    await tester.pump(ShowcaseCardImages.interval * 2);
    expect(controller.page, 0);
    await tester.pumpWidget(const SizedBox());
  });
}
