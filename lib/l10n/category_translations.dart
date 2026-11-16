import 'package:flutter/material.dart';

class CategoryTranslations {
  const CategoryTranslations._();

  static String translate(String? name, [Locale? locale]) {
    if (name == null || name.isEmpty) return '';
    final code = (locale?.languageCode ?? 'ar').toLowerCase();
    final entry = _map[name];
    if (entry == null) return name;
    return entry[code] ?? entry['ar'] ?? name;
  }

  static const Map<String, Map<String, String>> _map = <String, Map<String, String>>{












































































































  };
}
