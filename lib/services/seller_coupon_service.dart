import '../models/seller_coupon.dart';
import 'api_client.dart';

/// كوبونات البائع (نفس قواعد لوحة البائع في الموقع).
class SellerCouponService {
  SellerCouponService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  Map<String, dynamic> _map(dynamic raw) =>
      raw is Map ? Map<String, dynamic>.from(raw) : <String, dynamic>{};

  Future<SellerCouponsPage> list() async =>
      SellerCouponsPage.fromJson(_map(await _api.get('/seller/coupons')));

  /// يعيد رسالة الخادم (مثلاً: بانتظار موافقة الإدارة).
  Future<String> create(Map<String, dynamic> body) async =>
      '${_map(await _api.post('/seller/coupons', body: body))['message'] ?? ''}';

  Future<String> update(int id, Map<String, dynamic> body) async =>
      '${_map(await _api.put('/seller/coupons/$id', body: body))['message'] ?? ''}';

  Future<SellerCoupon> toggle(int id) async => SellerCoupon.fromJson(
      _map(_map(await _api.post('/seller/coupons/$id/toggle'))['data']));

  Future<void> delete(int id) => _api.delete('/seller/coupons/$id');
}
