import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart'
    show SharedPreferences;

/// «شاهدته مؤخراً»: أرقام آخر المنتجات المفتوحة، محفوظة على الهاتف فقط.
/// [changes] يتغير مع كل تعديل لتحدّث الرئيسية قائمتها عند الرجوع إليها.
class RecentlyViewedStore {
  RecentlyViewedStore._();

  static const String _key = 'trendsham_recently_viewed';
  static const int maxItems = 20;

  static final ValueNotifier<int> changes = ValueNotifier<int>(0);

  /// الأحدث أولاً.
  static Future<List<int>> ids() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return (prefs.getStringList(_key) ?? const [])
          .map(int.tryParse)
          .whereType<int>()
          .toList();
    } catch (_) {
      return [];
    }
  }

  static Future<void> add(int productId) async {
    if (productId <= 0) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = (prefs.getStringList(_key) ?? <String>[])
        ..remove('$productId')
        ..insert(0, '$productId');
      await prefs.setStringList(_key, list.take(maxItems).toList());
      changes.value++;
    } catch (_) {
      // السجل ميزة مساعدة: فشل الحفظ لا يمنع فتح المنتج
    }
  }

  static Future<void> clear() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
      changes.value++;
    } catch (_) {}
  }
}
