import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/category.dart';

void main() {
  test('parses nested active subcategories from the categories API', () {
    final category = Category.fromJson({
      'id': 1,
      'slug': 'gardens',
      'name': 'الحدائق والنباتات',
      'children': [
        {
          'id': 2,
          'slug': 'indoor-plants',
          'name': 'نباتات منزلية',
          'children': [],
        },
      ],
    });

    expect(category.children, hasLength(1));
    expect(category.children.single.slug, 'indoor-plants');
    expect(category.children.single.name, 'نباتات منزلية');
  });
}
