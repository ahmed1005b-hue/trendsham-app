import 'package:shared_preferences/shared_preferences.dart' show SharedPreferences;

class ConsentService {
  static const String key = 'ts_consent_choice';
  static const String accepted = 'accepted';
  static const String rejected = 'rejected';

  static Future<String?> getChoice() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(key);
  }

  static Future<bool> hasChoice() async {
    final choice = await getChoice();
    return choice == accepted || choice == rejected;
  }

  static Future<void> accept() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, accepted);
  }

  static Future<void> reject() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(key, rejected);
  }

  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(key);
  }
}
