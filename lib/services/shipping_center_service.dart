import 'api_client.dart';

/// مركز من مراكز شركة الشحن كرم.
class ShippingCenter {
  final int id;
  final String name;
  final String address;
  final String phone;
  final String? hours;

  const ShippingCenter({
    required this.id,
    required this.name,
    required this.address,
    required this.phone,
    this.hours,
  });

  factory ShippingCenter.fromJson(Map<String, dynamic> json) => ShippingCenter(
        id: int.tryParse(json['id'].toString()) ?? 0,
        name: json['name']?.toString() ?? '',
        address: json['address']?.toString() ?? '',
        phone: json['phone']?.toString() ?? '',
        hours: json['hours']?.toString(),
      );
}

/// مراكز محافظة واحدة. governorateLabel مترجم من الخادم.
class ShippingCenterGroup {
  final String governorateLabel;
  final List<ShippingCenter> centers;

  const ShippingCenterGroup(
      {required this.governorateLabel, required this.centers});

  factory ShippingCenterGroup.fromJson(Map<String, dynamic> json) =>
      ShippingCenterGroup(
        governorateLabel: (json['governorate_label'] ?? json['governorate'])
                ?.toString() ??
            '',
        centers: (json['centers'] is List)
            ? (json['centers'] as List)
                .whereType<Map>()
                .map((m) => ShippingCenter.fromJson(Map<String, dynamic>.from(m)))
                .toList()
            : const [],
      );
}

class ShippingCenterService {
  ShippingCenterService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;
  static List<ShippingCenterGroup>? _cache;

  /// المراكز الفعّالة مجمّعة بالمحافظة (تُحفظ في الذاكرة طوال الجلسة).
  Future<List<ShippingCenterGroup>> groups() async {
    if (_cache != null) return _cache!;
    final data = await _api.get('/shipping-centers');
    final list =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    final groups = list
        .whereType<Map>()
        .map((m) => ShippingCenterGroup.fromJson(Map<String, dynamic>.from(m)))
        .toList();
    if (groups.isNotEmpty) _cache = groups;
    return groups;
  }
}
