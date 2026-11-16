library;

import 'package:flutter/foundation.dart' show kDebugMode, kReleaseMode;

/// Quick API base URL guide:
/// - Real phone on same Wi-Fi: http://<LAN-IP>/trendsham/public/api/v1
/// - Android Emulator:         http://10.0.2.2/trendsham/public/api/v1
/// - iOS Simulator/localhost:  http://127.0.0.1/trendsham/public/api/v1
/// Run with override:
/// flutter run --dart-define=API_BASE_URL=http://192.168.1.105/trendsham/public/api/v1 --dart-define=STORAGE_BASE_URL=http://192.168.1.105/trendsham/public
class ApiConfig {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://192.168.1.106/trendsham/public/api/v1',
  );

  /// Base URL without /api/v1, used for storage/image URLs.
  static const String storageBaseUrl = String.fromEnvironment(
    'STORAGE_BASE_URL',
    defaultValue: 'http://192.168.1.106/trendsham/public',
  );

  static bool get allowInsecureHttp => !kReleaseMode;

  static bool isTransportAllowed(String url, {bool allowInsecureHttp = false}) {
    final scheme = Uri.tryParse(url)?.scheme.toLowerCase();
    return scheme == 'https' || (allowInsecureHttp && scheme == 'http');
  }

  static String debugContext() =>
      'API=$baseUrl | storage=$storageBaseUrl | insecureHttp=$allowInsecureHttp | debug=$kDebugMode';
}
