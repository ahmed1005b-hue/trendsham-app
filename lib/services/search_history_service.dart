import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

/// خدمة إدارة سجل البحث الذكي وحفظ عمليات البحث السابقة
class SearchHistoryService {
  static const String _key = 'trendsham_recent_searches';
  static const int _maxItems = 10;

  static const List<String> popularSearches = [
    'عطور',
    'إلكترونيات',
    'أزياء نسائية',
    'أزياء رجالية',
    'ساعات',
    'أحذية',
    'حقائب',
    'المنزل والمطبخ',
    'تنزيلات',
  ];

  /// جلب سجل البحث الأخير
  static Future<List<String>> getRecentSearches() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_key) ?? [];
    } catch (_) {
      return [];
    }
  }

  /// إضافة عملية بحث جديدة إلى أعلى القائمة
  static Future<void> addQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];

      // إزالة أي تكرار لنفس الكلمة ووضعها في المقدمة
      list.removeWhere((item) => item.toLowerCase() == clean.toLowerCase());
      list.insert(0, clean);

      if (list.length > _maxItems) {
        list.removeRange(_maxItems, list.length);
      }

      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  /// حذف كلمة معينة من السجل
  static Future<void> removeQuery(String query) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_key) ?? [];
      list.removeWhere((item) => item.toLowerCase() == query.trim().toLowerCase());
      await prefs.setStringList(_key, list);
    } catch (_) {}
  }

  /// مسح سجل البحث كاملاً
  static Future<void> clearHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (_) {}
  }
}
