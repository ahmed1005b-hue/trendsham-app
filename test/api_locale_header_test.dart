import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:trendsham/providers/app_settings_provider.dart';
import 'package:trendsham/services/api_client.dart';

/// لغة الواجهة تُرسل للسيرفر (X-App-Locale) ليرد برسائله وإشعاراته بنفس اللغة.
void main() {
  test('the API language follows the saved and the changed UI language',
      () async {
    SharedPreferences.setMockInitialValues({'app.locale': 'tr'});
    final settings = AppSettingsProvider(
        preferences: await SharedPreferences.getInstance());

    await settings.load();
    expect(ApiClient.languageCode, 'tr');

    await settings.setLocale(const Locale('en'));
    expect(ApiClient.languageCode, 'en');

    await settings.setLocale(const Locale('ar'));
    expect(ApiClient.languageCode, 'ar');
  });
}
