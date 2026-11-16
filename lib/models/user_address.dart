/// عنوان شحن محفوظ (حتى 3 لكل مستخدم) — يطابق UserAddress::toApiArray في السيرفر.
class UserAddress {
  static const maxPerUser = 3;
  static const labels = {'home': 'البيت', 'work': 'العمل', 'other': 'آخر'};

  final int id;
  final String label; // home | work | other
  final String labelText;
  final String city;
  final String details;
  final double? latitude;
  final double? longitude;
  final String? mapUrl;
  final bool isDefault;

  /// النص الذي يُنسخ في "عنوان التوصيل" عند الطلب (يبنيه السيرفر).
  final String shippingText;

  const UserAddress({
    required this.id,
    required this.label,
    required this.labelText,
    required this.city,
    required this.details,
    this.latitude,
    this.longitude,
    this.mapUrl,
    required this.isDefault,
    required this.shippingText,
  });

  bool get hasLocation => latitude != null && longitude != null;

  static double? _num(dynamic v) => v == null ? null : double.tryParse(v.toString());

  factory UserAddress.fromJson(Map<String, dynamic> j) {
    final label = (j['label'] ?? 'other').toString();
    final city = (j['city'] ?? '').toString();
    final details = (j['details'] ?? '').toString();
    return UserAddress(
      id: (j['id'] as num).toInt(),
      label: label,
      labelText: (j['label_text'] ?? labels[label] ?? label).toString(),
      city: city,
      details: details,
      latitude: _num(j['latitude']),
      longitude: _num(j['longitude']),
      mapUrl: j['map_url']?.toString(),
      isDefault: j['is_default'] == true,
      shippingText: (j['shipping_text'] ?? '$city - $details').toString(),
    );
  }
}
