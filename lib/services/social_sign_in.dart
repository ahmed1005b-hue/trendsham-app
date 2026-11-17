import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'api_client.dart';

/// الدخول بـ Google وFacebook (للعملاء فقط).
///
/// الإعداد بدون أي مفتاح سري داخل الكود:
/// - Google: يكفي تفعيله في الخادم (.env)؛ معرّف عميل الويب العام يصل من
///   /auth/social/providers (ويمكن تثبيته بـ `--dart-define=GOOGLE_SERVER_CLIENT_ID=`).
/// - Facebook: تفعيله في الخادم + facebook.appId/clientToken في android/local.properties
///   (يُعطَّل يدوياً بـ `--dart-define=FACEBOOK_LOGIN=false`).
/// الزر يظهر فقط إذا كان المزوّد مفعّلاً هنا وفي الخادم معاً.
class SocialSignIn {
  SocialSignIn({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  static const googleServerClientId =
      String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');
  static const facebookEnabled =
      bool.fromEnvironment('FACEBOOK_LOGIN', defaultValue: true);

  static bool _googleReady = false;
  static String _googleClientId = googleServerClientId;

  /// المزوّدات المتاحة الآن (مفعّلة في التطبيق والخادم).
  Future<Set<String>> availableProviders() async {
    try {
      final data = await _api.get('/auth/social/providers', withAuth: false);
      if (data is! Map) return {};
      final serverId = data['google_client_id'];
      if (_googleClientId.isEmpty && serverId is String) {
        _googleClientId = serverId;
      }
      return {
        if (data['google'] == true && _googleClientId.isNotEmpty) 'google',
        if (data['facebook'] == true && facebookEnabled) 'facebook',
      };
    } catch (_) {
      return {};
    }
  }

  /// رمز يرسله التطبيق للخادم، أو null إن ألغى المستخدم.
  Future<String?> token(String provider) =>
      provider == 'google' ? _google() : _facebook();

  Future<String?> _google() async {
    final signIn = GoogleSignIn.instance;
    if (!_googleReady) {
      await signIn.initialize(serverClientId: _googleClientId);
      _googleReady = true;
    }
    try {
      final account = await signIn.authenticate();
      return account.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  Future<String?> _facebook() async {
    final result = await FacebookAuth.instance
        .login(permissions: const ['email', 'public_profile']);
    return switch (result.status) {
      LoginStatus.success => result.accessToken?.tokenString,
      LoginStatus.cancelled => null,
      _ => throw Exception(result.message ?? 'facebook login failed'),
    };
  }

  /// تسجيل الخروج من المزوّد أيضاً، ليختار المستخدم حساباً آخر في المرة القادمة.
  static Future<void> signOutProviders() async {
    try {
      if (_googleReady) await GoogleSignIn.instance.signOut();
    } catch (_) {}
    try {
      if (facebookEnabled) await FacebookAuth.instance.logOut();
    } catch (_) {}
  }
}
