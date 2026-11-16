import 'package:flutter/foundation.dart';

import '../../models/product.dart';
import '../../models/product_options.dart';

const int maxOptionCombinations = 200;

/// A color of the editor. [key] identifies it inside the matrix and never
/// changes; [name] is what is submitted as `color_name`; [originalKey] is the
/// saved `color` value of a legacy variant (sent as `original_color`).
class OptionColor {
  final String key;
  final String name;
  final String? hex;
  final String? originalKey;

  const OptionColor({
    required this.key,
    required this.name,
    this.hex,
    this.originalKey,
  });

  OptionColor withHex(String newHex) {
    return OptionColor(
      key: key,
      name: name,
      hex: canonicalHex(newHex),
      originalKey: originalKey,
    );
  }
}

class OptionCombo {
  bool available;
  String stock;
  String priceIncrease;
  String sku;

  OptionCombo({
    this.available = true,
    this.stock = '',
    this.priceIncrease = '',
    this.sku = '',
  });
}

/// State of the colors x sizes editor. Combination values are stored by
/// `'${colorKey ?? ''}|${size ?? ''}'`, so they survive toggling.
class ProductOptionsController extends ChangeNotifier {
  ProductOptionsController(this.catalog);

  final ProductOptionsCatalog catalog;

  bool enabled = false;

  final List<OptionColor> _colors = [];
  final List<String> _sizes = [];
  final Map<String, OptionCombo> _combos = {};
  final Map<String, String> _originalKeys = {};
  int _droppedOnLoad = 0;

  /// عدد الخيارات المحفوظة التي لا يمثلها أي صف في الجدول بعد التحميل
  /// (مثل لون فارغ بجانب ألوان أخرى)، وستُحذف عند الحفظ.
  int get droppedOnLoad => _droppedOnLoad;

  List<OptionColor> get colors => List.unmodifiable(_colors);

  List<String> get sizes => List.unmodifiable(_sizes);

  void setEnabled(bool value) {
    enabled = value;
    notifyListeners();
  }

  bool isPaletteSelected(ColorOption c) {
    final key = canonicalHex(c.hex);
    return _colors.any((e) => e.key == key);
  }

  void togglePaletteColor(ColorOption c) {
    final key = canonicalHex(c.hex);
    final index = _colors.indexWhere((e) => e.key == key);
    if (index >= 0) {
      _colors.removeAt(index);
    } else {
      _colors.add(OptionColor(
        key: key,
        name: c.name,
        hex: key,
        originalKey: _originalKeys[key],
      ));
    }
    notifyListeners();
  }

  String? addCustomColor(String name, String hex) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) {
      return 'اكتب اسم اللون.';
    }
    if (!isHexColor(hex)) {
      return null;
    }
    final canonical = canonicalHex(hex);
    final exists = _colors.any((e) => e.key == canonical || e.hex == canonical);
    if (exists) {
      return 'هذا اللون مضاف مسبقاً.';
    }
    _colors.add(OptionColor(
      key: canonical,
      name: trimmed,
      hex: canonical,
      originalKey: _originalKeys[canonical],
    ));
    notifyListeners();
    return null;
  }

  /// Returns the Arabic error when another selected color already has [hex].
  String? recolor(String key, String hex) {
    if (!isHexColor(hex)) {
      return null;
    }
    final index = _colors.indexWhere((e) => e.key == key);
    if (index < 0) {
      return null;
    }
    final canonical = canonicalHex(hex);
    final taken = _colors.any(
      (e) => e.key != key && (e.key == canonical || e.hex == canonical),
    );
    if (taken) {
      return 'هذا اللون مضاف مسبقاً.';
    }
    _colors[index] = _colors[index].withHex(canonical);
    notifyListeners();
    return null;
  }

  void removeColor(String key) {
    _colors.removeWhere((e) => e.key == key);
    notifyListeners();
  }

  void toggleSize(String size) {
    final trimmed = size.trim();
    if (trimmed.isEmpty) {
      return;
    }
    final index = _sizes.indexWhere((e) => _sameSize(e, trimmed));
    if (index >= 0) {
      _sizes.removeAt(index);
    } else {
      _sizes.add(trimmed);
    }
    notifyListeners();
  }

  /// Returns false when the size is blank or already selected (ignoring case
  /// and spaces). A size matching a size-system size is stored with the
  /// system's spelling.
  bool addCustomSize(String size) {
    final trimmed = size.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (_sizes.any((e) => _sameSize(e, trimmed))) {
      return false;
    }
    _sizes.add(_systemSpelling(trimmed) ?? trimmed);
    notifyListeners();
    return true;
  }

  List<({OptionColor? color, String? size})> get combinations {
    if (_colors.isEmpty && _sizes.isEmpty) {
      return const [];
    }
    final colorList = _colors.isEmpty ? <OptionColor?>[null] : _colors;
    final sizeList = _sizes.isEmpty ? <String?>[null] : _sizes;
    return [
      for (final color in colorList)
        for (final size in sizeList) (color: color, size: size),
    ];
  }

  OptionCombo combo(String? colorKey, String? size) {
    return _combos.putIfAbsent(_comboKey(colorKey, size), OptionCombo.new);
  }

  /// يُستدعى بعد تعديل [OptionCombo] مباشرة ليتحدّث المخزون الإجمالي.
  void comboChanged() {
    notifyListeners();
  }

  void setAllStock(String v) {
    for (final e in combinations) {
      combo(e.color?.key, e.size).stock = v;
    }
    notifyListeners();
  }

  void setAllPriceIncrease(String v) {
    for (final e in combinations) {
      combo(e.color?.key, e.size).priceIncrease = v;
    }
    notifyListeners();
  }

  void setColorStock(String colorKey, String v) {
    for (final e in combinations) {
      if (e.color?.key == colorKey) {
        combo(e.color?.key, e.size).stock = v;
      }
    }
    notifyListeners();
  }

  int get totalStock {
    var total = 0;
    for (final e in combinations) {
      final c = combo(e.color?.key, e.size);
      if (c.available) {
        total += int.tryParse(c.stock.trim()) ?? 0;
      }
    }
    return total;
  }

  int get availableCount {
    return combinations
        .where((e) => combo(e.color?.key, e.size).available)
        .length;
  }

  String? validate() {
    if (!enabled) {
      return null;
    }
    final count = availableCount;
    if (count == 0) {
      return 'فعّل خياراً واحداً على الأقل، أو أوقف الألوان والمقاسات.';
    }
    if (count > maxOptionCombinations) {
      return 'عدد الخيارات كبير جداً (الحد 200). قلّل الألوان أو المقاسات.';
    }
    return null;
  }

  List<Map<String, String>> toVariantMaps() {
    if (!enabled) {
      return [];
    }
    final out = <Map<String, String>>[];
    for (final e in combinations) {
      final c = combo(e.color?.key, e.size);
      if (!c.available) {
        continue;
      }
      final color = e.color;
      out.add({
        'color': color == null ? '' : (color.hex ?? color.key),
        'color_name': color?.name ?? '',
        'size': e.size ?? '',
        'sku': c.sku.trim(),
        'price_adjustment': _normalizePrice(c.priceIncrease),
        'stock_quantity': _blankToZero(c.stock),
        if (color?.originalKey != null) 'original_color': color!.originalKey!,
      });
    }
    return out;
  }

  /// Rebuilds the matrix from saved variants. Variants that collapse to the
  /// same combination keep the first row's identity and add up their stock.
  void load(List<ProductVariant> variants) {
    _colors.clear();
    _sizes.clear();
    _combos.clear();
    _originalKeys.clear();
    _droppedOnLoad = 0;
    enabled = variants.isNotEmpty;
    final loadedKeys = <String>[];

    for (final v in variants) {
      final color = _colorFromVariant(v);
      String? colorKey;
      if (color != null) {
        if (!_colors.any((e) => e.key == color.key)) {
          _colors.add(color);
          final original = color.originalKey;
          if (original != null) {
            _originalKeys[color.key] = original;
          }
        }
        colorKey = color.key;
      }

      String? size;
      final rawSize = v.size?.trim() ?? '';
      if (rawSize.isNotEmpty) {
        final index = _sizes.indexWhere((e) => _sameSize(e, rawSize));
        if (index >= 0) {
          size = _sizes[index];
        } else {
          _sizes.add(rawSize);
          size = rawSize;
        }
      }

      final key = _comboKey(colorKey, size);
      loadedKeys.add(key);
      final existingCombo = _combos[key];
      if (existingCombo != null) {
        final sum = (int.tryParse(existingCombo.stock) ?? 0) + v.stockQuantity;
        existingCombo.stock = '$sum';
        continue;
      }
      _combos[key] = OptionCombo(
        stock: '${v.stockQuantity}',
        priceIncrease: _formatPrice(v.priceAdjustment),
        sku: v.sku ?? '',
      );
    }
    final representedKeys = <String>{};
    for (final e in combinations) {
      final key = _comboKey(e.color?.key, e.size);
      representedKeys.add(key);
      _combos.putIfAbsent(key, () => OptionCombo(available: false));
    }
    _droppedOnLoad = loadedKeys.where((k) => !representedKeys.contains(k)).length;
    notifyListeners();
  }

  OptionColor? _colorFromVariant(ProductVariant v) {
    final rawColor = v.color?.trim() ?? '';
    final rawName = v.colorName?.trim() ?? '';
    if (rawColor.isEmpty && rawName.isEmpty) {
      return null;
    }
    final saved = rawColor.isNotEmpty ? rawColor : rawName;

    ColorOption? palette;
    if (isHexColor(rawColor)) {
      palette = catalog.byHex(rawColor);
    }
    if (!isHexColor(rawColor)) {
      palette ??= catalog.matchName(rawName.isNotEmpty ? rawName : rawColor);
      palette ??= catalog.matchName(rawColor);
    }

    if (palette != null) {
      final key = canonicalHex(palette.hex);
      return OptionColor(
        key: key,
        name: palette.name,
        hex: key,
        originalKey: saved == key ? null : saved,
      );
    }
    if (isHexColor(rawColor)) {
      final key = canonicalHex(rawColor);
      return OptionColor(
        key: key,
        name: rawName.isNotEmpty ? rawName : key,
        hex: key,
        originalKey: saved == key ? null : saved,
      );
    }
    final hex = isHexColor(v.colorHex) ? canonicalHex(v.colorHex!) : null;
    return OptionColor(
      key: saved,
      name: rawName.isNotEmpty ? rawName : saved,
      hex: hex,
      originalKey: saved,
    );
  }

  String? _systemSpelling(String size) {
    for (final system in catalog.sizeSystems) {
      for (final s in system.sizes) {
        if (_sameSize(s, size)) {
          return s;
        }
      }
    }
    return null;
  }

  static bool _sameSize(String a, String b) => _foldSize(a) == _foldSize(b);

  static String _foldSize(String s) =>
      s.replaceAll(RegExp(r'\s+'), '').toLowerCase();

  static String _comboKey(String? colorKey, String? size) =>
      '${colorKey ?? ''}|${size ?? ''}';

  static String _blankToZero(String v) {
    final t = v.trim();
    return t.isEmpty ? '0' : t;
  }

  /// يحوّل '.' إلى '0' و'5.' إلى '5' و'.5' إلى '0.5'، ويُبقي الباقي كما كتبه البائع.
  static String _normalizePrice(String v) {
    var t = v.trim();
    if (t.startsWith('.')) {
      t = '0$t';
    }
    if (t.endsWith('.')) {
      t = t.substring(0, t.length - 1);
    }
    return t.isEmpty ? '0' : t;
  }

  static String _formatPrice(double value) {
    if (value == 0) {
      return '';
    }
    return value == value.truncateToDouble() ? '${value.toInt()}' : '$value';
  }
}
