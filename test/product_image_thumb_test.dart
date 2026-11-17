import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/vendor.dart';

/// القوائم تستعمل الصورة الصغيرة، وصفحة المنتج تبقى على الأصلية.
void main() {
  Map<String, dynamic> productJson(Map<String, dynamic> image) => {
        'id': 1,
        'slug': 'shirt',
        'name': 'قميص',
        'price': 100,
        'stock_quantity': 3,
        'images': [image],
        'primary_image': image,
      };

  test('a product image keeps both the full and the small link', () {
    final product = Product.fromJson(productJson({
      'id': 7,
      'url': 'http://x/storage/products/a.jpg',
      'thumb_url': 'http://x/storage/thumbs/products/a.webp',
      'is_primary': true,
    }));

    expect(product.primaryImage!.url, 'http://x/storage/products/a.jpg');
    expect(product.primaryImage!.listUrl,
        'http://x/storage/thumbs/products/a.webp');
    expect(product.images.first.listUrl,
        'http://x/storage/thumbs/products/a.webp');
  });

  test('without a small copy the list falls back to the full image', () {
    final image = ProductImage.fromJson(
        {'id': 1, 'url': 'http://x/a.jpg', 'is_primary': true});

    expect(image.listUrl, 'http://x/a.jpg');
    expect(
        ProductImage(
                id: 2, url: 'http://x/b.jpg', isPrimary: false, thumbUrl: '')
            .listUrl,
        'http://x/b.jpg');
  });
}
