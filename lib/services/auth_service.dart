import '../models/user.dart';
import 'package:image_picker/image_picker.dart';
import 'api_exception.dart';
import 'api_client.dart';

class AuthService {
  final ApiClient _api = ApiClient();

  /// رسالة من السيرفر عند آخر دخول (مثل: أُعيد تفعيل حسابك / أُلغي طلب الحذف).
  String? lastLoginNotice;

  Future<void> register({
    required String accountType,
    required String firstName,
    required String lastName,
    required String phone,
    String? address,
    required String email,
    required String password,
    required String passwordConfirmation,
    String? storeName,
  }) async {
    await _api.post('/auth/register', withAuth: false, body: {
      'account_type': accountType,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'address': address,
      'email': email,
      'password': password,
      'password_confirmation': passwordConfirmation,
      if (storeName != null) 'store_name': storeName,
    });
  }

  Future<AppUser?> verifyRegistration(
      {required String phone,
      required String code,
      XFile? identityDocument}) async {
    final data = identityDocument == null
        ? await _api.post('/auth/register/verify',
            withAuth: false, body: {'phone': phone, 'code': code})
        : await _api.postMultipartNoAuth(
            '/auth/register/verify',
            fields: {'phone': phone, 'code': code},
            files: {'identity_document': identityDocument},
          );

    if (data['pending_approval'] == true) return null;

    await _api.saveToken(data['token']);
    return AppUser.fromJson(data['user']);
  }

  Future<AppUser> login(
      {required String identifier, required String password}) async {
    final data = await _api.post('/auth/login', withAuth: false, body: {
      'identifier': identifier,
      'password': password,
    });

    await _api.saveToken(data['token']);
    final notice = data is Map ? data['notice'] : null;
    lastLoginNotice = notice is String && notice.isNotEmpty ? notice : null;
    try {
      final user = await currentUser();
      if (user == null) {
        throw const ApiException('تعذّر تحميل بيانات الحساب بعد تسجيل الدخول.');
      }
      return user;
    } catch (_) {
      await _api.clearToken();
      rethrow;
    }
  }

  Future<void> requestPasswordReset({required String identifier}) async {
    await _api.post('/auth/forgot-password', withAuth: false, body: {
      'identifier': identifier,
    });
  }

  Future<void> resetPassword({
    required String identifier,
    required String code,
    required String password,
    required String passwordConfirmation,
  }) async {
    await _api.post('/auth/reset-password', withAuth: false, body: {
      'identifier': identifier,
      'code': code,
      'password': password,
      'password_confirmation': passwordConfirmation,
    });
  }

  Future<void> logout() async {
    try {
      await _api.post('/auth/logout');
    } finally {
      await _api.clearToken();
    }
  }

  /// السيرفر أنهى الجلسة بنفسه (إيقاف/حذف الحساب): نمسح التوكن محلياً فقط.
  Future<void> clearLocalSession() => _api.clearToken();

  Future<AppUser?> currentUser() async {
    final t = await _api.token;
    if (t == null) return null;

    try {
      final data = await _api.get('/auth/me');
      return AppUser.fromJson(data['data'] ?? data);
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        await _api.clearToken();
      }
      rethrow;
    }
  }
}
