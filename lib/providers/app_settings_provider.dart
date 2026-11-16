import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/api_client.dart';

class AppSettingsProvider extends ChangeNotifier {
  AppSettingsProvider({SharedPreferences? preferences})
      : _preferences = preferences;

  static const _localeKey = 'app.locale';

  SharedPreferences? _preferences;
  Locale _locale = const Locale('ar');

  Locale get locale => _locale;

  Future<void> load() async {
    _preferences ??= await SharedPreferences.getInstance();
    final languageCode = _preferences!.getString(_localeKey);
    if (languageCode != null &&
        const {'ar', 'en', 'tr'}.contains(languageCode)) {
      _locale = Locale(languageCode);
    }
    ApiClient.languageCode = _locale.languageCode;
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    if (!const {'ar', 'en', 'tr'}.contains(locale.languageCode)) return;
    if (_locale == locale) return;
    _locale = locale;
    ApiClient.languageCode = locale.languageCode;
    notifyListeners();
    _preferences ??= await SharedPreferences.getInstance();
    await _preferences!.setString(_localeKey, locale.languageCode);
  }
}
