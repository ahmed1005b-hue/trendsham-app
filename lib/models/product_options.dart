import 'package:flutter/painting.dart';

/// Color of the shared catalog. [name] is the canonical Arabic name (submitted
/// to the server); [label] is the display text in the app language.
class ColorOption {
  final String name;
  final String label;
  final String hex;

  const ColorOption({
    required this.name,
    required this.label,
    required this.hex,
  });

  factory ColorOption.fromJson(Map<String, dynamic> json) {
    final name = json['name']?.toString() ?? '';
    return ColorOption(
      name: name,
      label: json['label']?.toString() ?? name,
      hex: json['hex']?.toString() ?? '',
    );
  }
}

class SizeSystem {
  final String key;
  final String label;
  final List<String> sizes;

  const SizeSystem({
    required this.key,
    required this.label,
    required this.sizes,
  });

  factory SizeSystem.fromJson(Map<String, dynamic> json) {
    return SizeSystem(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sizes: (json['sizes'] is List)
          ? (json['sizes'] as List).map((s) => s.toString()).toList()
          : const [],
    );
  }
}

class ProductOptionsCatalog {
  final List<ColorOption> colors;
  final List<SizeSystem> sizeSystems;

  const ProductOptionsCatalog({
    required this.colors,
    required this.sizeSystems,
  });

  factory ProductOptionsCatalog.fromJson(Map<String, dynamic> json) {
    return ProductOptionsCatalog(
      colors: (json['colors'] is List)
          ? (json['colors'] as List)
              .whereType<Map>()
              .map((c) => ColorOption.fromJson(Map<String, dynamic>.from(c)))
              .toList()
          : const [],
      sizeSystems: (json['size_systems'] is List)
          ? (json['size_systems'] as List)
              .whereType<Map>()
              .map((s) => SizeSystem.fromJson(Map<String, dynamic>.from(s)))
              .toList()
          : const [],
    );
  }

  ColorOption? byHex(String hex) {
    if (!isHexColor(hex)) return null;
    final target = canonicalHex(hex);
    for (final c in colors) {
      if (c.hex.toUpperCase() == target) return c;
    }
    return null;
  }

  ColorOption? matchName(String? name) {
    if (name == null || name.trim().isEmpty) return null;
    final target = normalizeColorName(name);
    for (final c in colors) {
      if (normalizeColorName(c.name) == target) return c;
    }
    return null;
  }
}

final RegExp _whitespace = RegExp(r'\s+', unicode: true);
final RegExp _arabicMarks = RegExp('[ـً-ْ]');
/// Folded like the server: hamzas to alef, alef maqsura to yaa, taa marbuta to
/// haa (code points, so the source holds no Arabic literal to translate).
const List<(int, int)> _arabicFolds = [
  (0x0623, 0x0627),
  (0x0625, 0x0627),
  (0x0622, 0x0627),
  (0x0649, 0x064A),
  (0x0629, 0x0647),
];
final RegExp _hexPattern = RegExp(r'^#?[0-9A-Fa-f]{6}$');

/// Same rules as `ProductOptions::normalizeName` on the server.
String normalizeColorName(String input) {
  var s = input.replaceAll(RegExp('^[ \t\n\r\x00\x0B]+|[ \t\n\r\x00\x0B]+\$'), '');
  s = s.replaceAll(_whitespace, ' ');
  s = s.replaceAll(_arabicMarks, '');
  for (final (from, to) in _arabicFolds) {
    s = s.replaceAll(String.fromCharCode(from), String.fromCharCode(to));
  }
  return s.toLowerCase();
}

bool isHexColor(String? value) {
  return value != null && _hexPattern.hasMatch(value);
}

String canonicalHex(String value) {
  return '#${value.replaceFirst(RegExp('^#+'), '').toUpperCase()}';
}

/// Parses `#RRGGBB` (the `#` is optional); returns null for anything else.
Color? colorFromHex(String? value) {
  if (!isHexColor(value)) return null;
  final digits = canonicalHex(value!).substring(1);
  return Color(int.parse('FF$digits', radix: 16));
}
