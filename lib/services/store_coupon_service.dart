import 'api_client.dart';

/// "احفظ" كوبون المتجر في المحفظة.
class StoreCouponService {
  StoreCouponService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  /// يعيد رسالة النجاح من الخادم. أخطاء 409/410/404 تصل كـ ApiException برسالة عربية.
  Future<String> collect(int campaignId) async {
    final response = await _api.post('/coupons/$campaignId/collect');
    return (response is Map ? response['message']?.toString() : null) ??
        'حُفظ الكوبون في محفظتك';
  }
}
