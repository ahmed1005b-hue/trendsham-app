import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/product.dart';
import 'package:trendsham/models/product_options.dart';
import 'package:trendsham/screens/seller/product_options_controller.dart';

const _red = ColorOption(name: 'أحمر', label: 'Red', hex: '#D32F2F');
const _black = ColorOption(name: 'أسود', label: 'Black', hex: '#1A1A1A');

const _catalog = ProductOptionsCatalog(
  colors: [_red, _black],
  sizeSystems: [
    SizeSystem(key: 'letters', label: 'Letters', sizes: ['S', 'M', 'L', 'XL']),
  ],
);

ProductVariant _variant({
  String? color,
  String? colorName,
  String? size,
  int stock = 0,
  double priceAdjustment = 0,
  String? sku,
}) {
  return ProductVariant(
    id: 1,
    color: color,
    colorName: colorName,
    size: size,
    sku: sku,
    stockQuantity: stock,
    priceAdjustment: priceAdjustment,
  );
}

ProductOptionsController _controller() {
  return ProductOptionsController(_catalog)..setEnabled(true);
}

void main() {
  test('matrix is colors times sizes in selection order', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..togglePaletteColor(_black)
      ..toggleSize('M')
      ..toggleSize('L');
    expect(
      c.combinations.map((e) => '${e.color!.hex}-${e.size}').toList(),
      ['#D32F2F-M', '#D32F2F-L', '#1A1A1A-M', '#1A1A1A-L'],
    );
  });

  test('values survive toggling a size off and on', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..toggleSize('M');
    c.combo('#D32F2F', 'M').stock = '7';
    c
      ..toggleSize('M')
      ..toggleSize('M');
    expect(c.combo('#D32F2F', 'M').stock, '7');
  });

  test('duplicate custom color hex is refused', () {
    final c = _controller()..togglePaletteColor(_red);
    expect(c.addCustomColor('قرمزي', '#d32f2f'), 'هذا اللون مضاف مسبقاً.');
    expect(c.colors.length, 1);
    expect(c.addCustomColor('  ', '#123456'), 'اكتب اسم اللون.');
    expect(c.addCustomColor('زهري', '#FFC0CB'), isNull);
    expect(c.colors.length, 2);
  });

  test('duplicate size ignoring case and spaces', () {
    final c = _controller()..toggleSize('M');
    expect(c.addCustomSize(' m '), isFalse);
    expect(c.sizes, ['M']);
  });

  test('custom size matching a system size uses the system spelling', () {
    final c = _controller();
    expect(c.addCustomSize(' xl '), isTrue);
    expect(c.sizes, ['XL']);
    expect(c.addCustomSize('42 عريض'), isTrue);
    expect(c.sizes, ['XL', '42 عريض']);
  });

  test('legacy word color maps to palette and keeps original key', () {
    final c = ProductOptionsController(_catalog)
      ..load([
        _variant(
          color: 'اسود',
          colorName: 'اسود',
          size: 'M',
          stock: 4,
          priceAdjustment: 15,
        ),
      ]);
    expect(c.enabled, isTrue);
    expect(c.colors.single.key, '#1A1A1A');
    expect(c.colors.single.originalKey, 'اسود');
    final map = c.toVariantMaps().single;
    expect(map['color'], '#1A1A1A');
    expect(map['color_name'], 'أسود');
    expect(map['original_color'], 'اسود');
    expect(map['size'], 'M');
    expect(map['stock_quantity'], '4');
    expect(map['price_adjustment'], '15');
  });

  test('unknown legacy color stays custom with null hex', () {
    final c = ProductOptionsController(_catalog)
      ..load([_variant(color: 'زهري فاتح', size: 'M', stock: 2)]);
    expect(c.colors.single.key, 'زهري فاتح');
    expect(c.colors.single.hex, isNull);
    c.recolor('زهري فاتح', '#FFC0CB');
    final map = c.toVariantMaps().single;
    expect(map['color'], '#FFC0CB');
    expect(map['original_color'], 'زهري فاتح');
    expect(map['stock_quantity'], '2');
  });

  test('load merges variants that collapse to one combination', () {
    final c = ProductOptionsController(_catalog)
      ..load([
        _variant(color: 'اسود', colorName: 'اسود', size: 'M', stock: 4, sku: 'A'),
        _variant(color: 'أسود', colorName: 'أسود', size: 'M', stock: 3),
        _variant(color: 'اسود', colorName: 'اسود', size: 'm', stock: 1),
      ]);
    expect(c.colors.length, 1);
    expect(c.sizes, ['M']);
    final maps = c.toVariantMaps();
    expect(maps.length, 1);
    expect(maps.single['stock_quantity'], '8');
    expect(maps.single['original_color'], 'اسود');
    expect(maps.single['sku'], 'A');
  });

  test('unavailable combos are not sent and totals count only available', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..togglePaletteColor(_black)
      ..toggleSize('M')
      ..toggleSize('L');
    var n = 1;
    for (final e in c.combinations) {
      c.combo(e.color?.key, e.size).stock = '${n++}';
    }
    c.combo('#1A1A1A', 'L').available = false;
    expect(c.toVariantMaps().length, 3);
    expect(c.totalStock, 1 + 2 + 3);
    expect(c.availableCount, 3);
  });

  test('validate', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..toggleSize('M');
    expect(c.validate(), isNull);
    c.combo('#D32F2F', 'M').available = false;
    expect(c.validate(), 'فعّل خياراً واحداً على الأقل، أو أوقف الألوان والمقاسات.');

    final big = _controller();
    for (var i = 0; i < 201; i++) {
      big.addCustomSize('s$i');
    }
    expect(big.validate(), 'عدد الخيارات كبير جداً (الحد 200). قلّل الألوان أو المقاسات.');

    big.setEnabled(false);
    expect(big.validate(), isNull);
    expect(big.toVariantMaps(), isEmpty);
  });

  test('bulk setters and blank values', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..togglePaletteColor(_black)
      ..toggleSize('M');
    expect(c.toVariantMaps().first['stock_quantity'], '0');
    expect(c.toVariantMaps().first['price_adjustment'], '0');
    c.setAllStock('5');
    c.setColorStock('#D32F2F', '9');
    c.setAllPriceIncrease('20');
    expect(c.combo('#D32F2F', 'M').stock, '9');
    expect(c.combo('#1A1A1A', 'M').stock, '5');
    expect(c.totalStock, 14);
    expect(c.toVariantMaps().last['price_adjustment'], '20');
  });

  test('hex-saved color is not remapped to the palette by name', () {
    final c = ProductOptionsController(_catalog)
      ..load([_variant(color: '#000000', colorName: 'أسود', size: 'M')]);
    expect(c.colors.single.key, '#000000');
    expect(c.colors.single.hex, '#000000');
    expect(c.colors.single.originalKey, isNull);
    expect(c.toVariantMaps().single['color'], '#000000');
  });

  test('sparse saved variants do not create phantom combinations', () {
    final c = ProductOptionsController(_catalog)
      ..load([
        _variant(color: 'اسود', colorName: 'اسود', size: 'M', stock: 2),
        _variant(color: 'احمر', colorName: 'احمر', size: 'L', stock: 3),
      ]);
    expect(c.combinations.length, 4);
    expect(c.availableCount, 2);
    expect(c.toVariantMaps().length, 2);
  });

  test('recolor refuses a hex already used by another color', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..addCustomColor('زهري', '#FFC0CB');
    expect(c.recolor('#FFC0CB', '#d32f2f'), 'هذا اللون مضاف مسبقاً.');
    expect(c.colors.last.hex, '#FFC0CB');
    expect(c.recolor('#FFC0CB', '#112233'), isNull);
    expect(c.colors.last.hex, '#112233');
  });

  test('original key survives toggling a legacy color off and on', () {
    final c = ProductOptionsController(_catalog)
      ..load([_variant(color: 'اسود', colorName: 'اسود', size: 'M')])
      ..togglePaletteColor(_black)
      ..togglePaletteColor(_black);
    expect(c.toVariantMaps().single['original_color'], 'اسود');
  });

  test('toggleSize trims its argument', () {
    final c = _controller()
      ..toggleSize(' M ')
      ..toggleSize('M');
    expect(c.sizes, isEmpty);
  });

  test('malformed price increases are normalised for the server', () {
    final c = _controller()
      ..togglePaletteColor(_red)
      ..toggleSize('S')
      ..toggleSize('M')
      ..toggleSize('L')
      ..toggleSize('XL');
    c.combo('#D32F2F', 'S').priceIncrease = '.';
    c.combo('#D32F2F', 'M').priceIncrease = '5.';
    c.combo('#D32F2F', 'L').priceIncrease = '2.50';
    c.combo('#D32F2F', 'XL').priceIncrease = '.5';
    expect(
      c.toVariantMaps().map((m) => m['price_adjustment']).toList(),
      ['0', '5', '2.50', '0.5'],
    );
  });

  test('droppedOnLoad counts saved variants the matrix cannot show', () {
    final c = ProductOptionsController(_catalog)
      ..load([
        _variant(size: 'M', stock: 2),
        _variant(color: '#D32F2F', colorName: 'أحمر', size: 'M', stock: 3),
      ]);
    expect(c.droppedOnLoad, 1);
  });

  test('droppedOnLoad is zero when collisions merge or nothing is lost', () {
    final c = ProductOptionsController(_catalog)
      ..load([
        _variant(color: '#D32F2F', colorName: 'أحمر', size: 'M', stock: 3),
        _variant(color: '#D32F2F', colorName: 'أحمر', size: 'm', stock: 1),
      ]);
    expect(c.droppedOnLoad, 0);
    expect(c.combo('#D32F2F', 'M').stock, '4');
  });
}
