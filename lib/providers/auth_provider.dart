import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import '../models/user.dart';
import '../services/auth_service.dart';
import '../services/push_service.dart';

class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();

  AppUser? _user;
  bool _isLoading = true;

  AppUser? get user => _user;
  bool get isLoggedIn => _user != null;
  bool get isLoading => _isLoading;

  Future<void> loadFromStorage() async {
    _isLoading = true;
    notifyListeners();

    try {
      _user = await _authService.currentUser();
      if (_user != null) _registerPush();
    } catch (_) {
      _user = null;
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// يعيد رسالة السيرفر إن وُجدت (إعادة تفعيل الحساب أو إلغاء طلب حذفه).
  Future<String?> login(String identifier, String password) async {
    _user = await _authService.login(
      identifier: identifier,
      password: password,
    );
    notifyListeners();
    _registerPush();
    return _authService.lastLoginNotice;
  }

  /// الخطوة الثانية بعد TwoFactorRequired. يعيد رسالة السيرفر إن وُجدت.
  Future<String?> completeTwoFactor(String challenge, String code) async {
    _user = await _authService.completeTwoFactor(
      challenge: challenge,
      code: code,
    );
    notifyListeners();
    _registerPush();
    return _authService.lastLoginNotice;
  }

  /// دخول العميل برمز Google/Facebook. يعيد رسالة السيرفر إن وُجدت.
  Future<String?> socialLogin(String provider, String token) async {
    _user = await _authService.socialLogin(provider: provider, token: token);
    notifyListeners();
    _registerPush();
    return _authService.lastLoginNotice;
  }

  Future<void> startRegistration({
    required String accountType,
    required String firstName,
    required String lastName,
    required String phone,
    String? address,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? storeName,
    String? referralCode,
  }) async {
    await _authService.register(
      accountType: accountType,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      address: address,
      email: email,
      password: password,
      passwordConfirmation: passwordConfirmation,
      storeName: storeName,
      referralCode: referralCode,
    );
  }

  Future<bool> verifyRegistration(
    String phone,
    String code, {
    XFile? identityDocument,
  }) async {
    final user = await _authService.verifyRegistration(
      phone: phone,
      code: code,
      identityDocument: identityDocument,
    );
    if (user == null) return false;
    _user = user;
    notifyListeners();
    _registerPush();
    return true;
  }

  Future<void> logout() async {
    // قبل حذف توكن الدخول: لا تصل إشعارات هذا الحساب لهذا الهاتف بعد الخروج.
    await PushService.instance.unregisterDevice();
    await _authService.logout();
    _user = null;
    notifyListeners();
  }

  /// بعد إيقاف الحساب أو طلب حذفه: السيرفر ألغى التوكنات وأجهزة الإشعارات بنفسه.
  Future<void> closeLocalSession() async {
    await _authService.clearLocalSession();
    _user = null;
    notifyListeners();
  }

  /// بعد أن تظهر الشاشة الرئيسية: شرح وطلب الإذن ثم تسجيل الهاتف (لا ينتظره الدخول).
  void _registerPush() {
    Future.delayed(const Duration(milliseconds: 800), () {
      PushService.instance.registerDevice();
    });
  }

  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }
}
