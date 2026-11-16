import '../models/user_address.dart';
import 'api_client.dart';

/// عناوين الشحن المحفوظة: /api/v1/profile/addresses (القواعد يفرضها السيرفر).
class AddressService {
  final ApiClient _api;
  AddressService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<List<UserAddress>> list() async {
    final data = await _api.get('/profile/addresses');
    return ((data['data'] ?? []) as List)
        .map((e) => UserAddress.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Map<String, dynamic> _body({
    required String label,
    required String city,
    required String details,
    double? latitude,
    double? longitude,
    required bool isDefault,
  }) =>
      {
        'label': label,
        'city': city,
        'details': details,
        'latitude': latitude,
        'longitude': longitude,
        'is_default': isDefault,
      };

  Future<UserAddress> create({
    required String label,
    required String city,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final data = await _api.post('/profile/addresses',
        body: _body(
            label: label,
            city: city,
            details: details,
            latitude: latitude,
            longitude: longitude,
            isDefault: isDefault));
    return UserAddress.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  Future<UserAddress> update(
    int id, {
    required String label,
    required String city,
    required String details,
    double? latitude,
    double? longitude,
    bool isDefault = false,
  }) async {
    final data = await _api.put('/profile/addresses/$id',
        body: _body(
            label: label,
            city: city,
            details: details,
            latitude: latitude,
            longitude: longitude,
            isDefault: isDefault));
    return UserAddress.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  /// اقتراح (مدينة، تفاصيل) من الإحداثيات؛ null إن لم يُعرف العنوان أو فشل الطلب.
  /// مساعدة فقط — لا يُرمى خطأ لأن العنوان المكتوب يكفي.
  Future<({String city, String details})?> reverseGeocode(double lat, double lng) async {
    try {
      final data = await _api.get('/profile/addresses/reverse-geocode',
          query: {'latitude': '$lat', 'longitude': '$lng'});
      final d = data is Map ? data['data'] : null;
      if (d is! Map) return null;
      final city = (d['city'] ?? '').toString().trim();
      final details = (d['details'] ?? '').toString().trim();
      if (city.isEmpty && details.isEmpty) return null;
      return (city: city, details: details);
    } catch (_) {
      return null;
    }
  }

  Future<void> makeDefault(int id) => _api.post('/profile/addresses/$id/default');

  Future<void> delete(int id) => _api.delete('/profile/addresses/$id');
}
