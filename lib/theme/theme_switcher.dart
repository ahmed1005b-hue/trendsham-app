import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/app_localizations.dart';

/// المصدر الوحيد لوضع المظهر في التطبيق (فاتح / داكن / حسب الجهاز).
/// يستخدمه MaterialApp وزر التبديل في كل الواجهات وإعداد "المظهر" في الحساب.
class ThemeController extends ChangeNotifier {
  static const _modeKey = 'app.themeMode';
  // مفتاح الإصدار السابق (كان يحفظ فاتح/داكن فقط) — يُقرأ للترحيل ثم يُحذف.
  static const _legacyDarkKey = 'isDarkMode';

  static ThemeController? _instance;
  static ThemeController get instance {
    assert(_instance != null, 'ThemeController must be initialized first.');
    return _instance!;
  }

  ThemeMode _themeMode = ThemeMode.light;
  late SharedPreferences _prefs;

  ThemeMode get themeMode => _themeMode;

  /// هل المظهر الظاهر الآن داكن (يأخذ "حسب الجهاز" بالاعتبار).
  bool get isDarkMode => switch (_themeMode) {
        ThemeMode.dark => true,
        ThemeMode.light => false,
        ThemeMode.system =>
          WidgetsBinding.instance.platformDispatcher.platformBrightness ==
              Brightness.dark,
      };

  ThemeController({required SharedPreferences prefs}) {
    _prefs = prefs;
    final legacyDark = _prefs.getBool(_legacyDarkKey);
    if (legacyDark != null) {
      // هذا ما كان المستخدم يراه فعلاً قبل توحيد الإعداد
      _themeMode = legacyDark ? ThemeMode.dark : ThemeMode.light;
    } else {
      final saved = _prefs.getString(_modeKey);
      _themeMode = ThemeMode.values.firstWhere(
        (mode) => mode.name == saved,
        orElse: () => ThemeMode.light,
      );
    }
    _instance = this;
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_modeKey, mode.name);
    await _prefs.remove(_legacyDarkKey);
  }

  Future<void> toggleTheme() =>
      setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
}

/// زر تبديل الوضع الليلي/النهاري لأشرطة تطبيق البائع والمدير والموظف.
class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<ThemeController>();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      tooltip: context.tr(isDark ? 'الوضع النهاري' : 'الوضع الليلي'),
      onPressed: controller.toggleTheme,
      icon: Icon(isDark ? Icons.wb_sunny_rounded : Icons.dark_mode_rounded),
    );
  }
}
