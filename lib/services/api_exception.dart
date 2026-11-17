class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  const ApiException(this.message, {this.statusCode, this.errors});

  @override
  String toString() => message;
}

/// كلمة السر صحيحة والحساب يطلب رمز تطبيق المصادقة (التحقق بخطوتين).
class TwoFactorRequired implements Exception {
  const TwoFactorRequired(this.challenge, this.message);

  /// يُرسل مع الرمز إلى /auth/two-factor (صالح بضع دقائق).
  final String challenge;
  final String message;
}
