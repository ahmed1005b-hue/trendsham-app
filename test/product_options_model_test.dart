import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/product_options.dart';
import 'package:trendsham/models/vendor.dart';
import 'package:trendsham/services/seller_service.dart';

void main() {
  final catalogJson = {
    'colors': [
      {'name': 'أسود', 'label': 'Black', 'hex': '#1A1A1A'},
      {'name': 'أحمر', 'label': 'Red', 'hex': '#D32F2F'},
    ],
    'size_systems': [
      {
        'key': 'letters',
        'label': 'Letters',
        'sizes': ['XS', 'S', 'M'],
      },
    ],
  };

  test('catalog fromJson keeps name, label, hex and sizes', () {
    final c = ProductOptionsCatalog.fromJson(catalogJson);
    expect(c.colors.length, 2);
    expect(c.colors[1].name, 'أحمر');
    expect(c.colors[1].label, 'Red');
    expect(c.colors[1].hex, '#D32F2F');
    expect(c.sizeSystems.single.key, 'letters');
    expect(c.sizeSystems.single.label, 'Letters');
    expect(c.sizeSystems.single.sizes, ['XS', 'S', 'M']);
  });

  test('normalizeColorName unifies Arabic spellings', () {
    expect(normalizeColorName('اسود'), normalizeColorName('أسود'));
    expect(normalizeColorName(' أحمـــر '), normalizeColorName('احمر'));
    expect(normalizeColorName('Navy  BLUE'), 'navy blue');
    expect(normalizeColorName('مدرسة'), normalizeColorName('مدرسه'));
  });

  test('matchName and byHex find palette entries', () {
    final c = ProductOptionsCatalog.fromJson(catalogJson);
    expect(c.matchName('احمر')?.hex, '#D32F2F');
    expect(c.matchName('غير موجود'), isNull);
    expect(c.matchName(null), isNull);
    expect(c.byHex('d32f2f')?.name, 'أحمر');
    expect(c.byHex('#123456'), isNull);
  });

  test('hex helpers follow the PHP rules', () {
    expect(canonicalHex('d32f2f'), '#D32F2F');
    expect(isHexColor('#d32f2f'), isTrue);
    expect(isHexColor('d32f2f'), isTrue);
    expect(isHexColor('#fff'), isFalse);
    expect(isHexColor(null), isFalse);
    expect(colorFromHex('#FF0000'), const Color(0xFFFF0000));
    expect(colorFromHex('اسود'), isNull);
    expect(colorFromHex(null), isNull);
  });

  test('ProductVariant and ProductImage read color_hex', () {
    final v = ProductVariant.fromJson(
        {'id': 1, 'color': 'اسود', 'color_hex': '#1A1A1A'});
    expect(v.colorHex, '#1A1A1A');
    final i = ProductImage.fromJson(
        {'id': 2, 'url': 'x', 'color': 'اسود', 'color_hex': '#1A1A1A'});
    expect(i.colorHex, '#1A1A1A');
  });

  test('variantFields sends variant_original_color', () {
    final f = SellerService.variantFields([
      {
        'color': '#1A1A1A',
        'size': 'M',
        'stock_quantity': '2',
        'original_color': 'اسود'
      }
    ]);
    expect(f['variant_original_color[0]'], 'اسود');
    final g = SellerService.variantFields([
      {'color': '#1A1A1A', 'size': 'M', 'original_color': ' '}
    ]);
    expect(g.containsKey('variant_original_color[0]'), isFalse);
  });
}
