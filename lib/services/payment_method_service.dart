import 'api_client.dart';

class PaymentMethodService {
  final ApiClient _api = ApiClient();

  /// جلب طرق الدفع المسجلة للبائع
  Future<List<Map<String, dynamic>>> getPaymentMethods() async {
    final data = await _api.get('/seller/wallet/payment-methods');
    final list = data['payment_methods'] as List?;
    return (list ?? [])
        .whereType<Map>()
        .map((p) => Map<String, dynamic>.from(p))
        .toList();
  }

  /// الأنواع والجهات المتاحة (بنوك/محافظ) + الحد الأدنى للسحب
  Future<Map<String, dynamic>> payoutOptions() async {
    final data = await _api.get('/seller/wallet/payout-options');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// إضافة طريقة دفع جديدة
  Future<Map<String, dynamic>> addPaymentMethod({
    required String type,
    required String provider,
    required String accountNumber,
    required String accountHolderName,
    bool isDefault = false,
  }) async {
    final data = await _api.post('/seller/wallet/payment-methods', body: {
      'type': type,
      'provider': provider,
      'account_number': accountNumber,
      'account_holder_name': accountHolderName,
      'is_default': isDefault,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// حذف طريقة دفع
  Future<Map<String, dynamic>> deletePaymentMethod(int paymentMethodId) async {
    final data = await _api.delete(
      '/seller/wallet/payment-methods/$paymentMethodId',
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// تعيين طريقة دفع كافتراضية
  Future<Map<String, dynamic>> setDefaultPaymentMethod(
    int paymentMethodId,
  ) async {
    final data = await _api.post(
      '/seller/wallet/payment-methods/$paymentMethodId/default',
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}
