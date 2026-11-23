import 'api_client.dart';

/// سعر توصيل المتجر بنفسه إلى محافظة واحدة (بالليرة).
class StoreShippingRate {
  StoreShippingRate({
    required this.governorate,
    required this.label,
    required this.enabled,
    this.fee,
  });

  final String governorate;
  final String label;
  bool enabled;
  double? fee;

  factory StoreShippingRate.fromJson(Map<String, dynamic> json) =>
      StoreShippingRate(
        governorate: json['governorate']?.toString() ?? '',
        label: (json['label'] ?? json['governorate'])?.toString() ?? '',
        enabled: json['enabled'] == true,
        fee: (json['fee'] as num?)?.toDouble(),
      );
}

/// حالة التوصيل الخاص ودين المتجر للمنصة.
class SelfDeliveryStatus {
  const SelfDeliveryStatus({
    this.active = false,
    this.reason,
    this.debt = 0,
    this.limit = 0,
  });

  final bool active;
  final String? reason;
  final double debt;
  final double limit;

  factory SelfDeliveryStatus.fromJson(Map<String, dynamic>? json) =>
      SelfDeliveryStatus(
        active: json?['active'] == true,
        reason: json?['reason']?.toString(),
        debt: (json?['debt'] as num?)?.toDouble() ?? 0,
        limit: (json?['limit'] as num?)?.toDouble() ?? 0,
      );
}

/// إعدادات شحن المتجر (نفس صفحة «إعدادات الشحن» في لوحة البائع بالموقع).
class StoreShippingSettings {
  StoreShippingSettings({
    required this.mode,
    required this.rates,
    required this.status,
    this.freeOver,
    this.prepDays = 1,
    this.deliveryDays = 2,
    this.allowPickup = false,
    this.pickupAddress,
  });

  /// platform = شركة الشحن، self = المتجر يوصل بنفسه
  String mode;
  double? freeOver;
  int prepDays;
  int deliveryDays;
  bool allowPickup;
  String? pickupAddress;
  final List<StoreShippingRate> rates;
  final SelfDeliveryStatus status;

  factory StoreShippingSettings.fromJson(Map<String, dynamic> json) =>
      StoreShippingSettings(
        mode: json['mode']?.toString() ?? 'platform',
        freeOver: (json['free_over'] as num?)?.toDouble(),
        prepDays: (json['prep_days'] as num?)?.toInt() ?? 1,
        deliveryDays: (json['delivery_days'] as num?)?.toInt() ?? 2,
        allowPickup: json['allow_pickup'] == true,
        pickupAddress: json['pickup_address']?.toString(),
        rates: (json['rates'] as List? ?? const [])
            .whereType<Map>()
            .map(
                (r) => StoreShippingRate.fromJson(Map<String, dynamic>.from(r)))
            .toList(),
        status: SelfDeliveryStatus.fromJson(json['status'] is Map
            ? Map<String, dynamic>.from(json['status'])
            : null),
      );

  /// جسم الحفظ بنفس شكل نموذج الموقع: rates[محافظة] = {enabled, fee}
  Map<String, dynamic> toJson() => {
        'mode': mode,
        'free_over': freeOver,
        'prep_days': prepDays,
        'delivery_days': deliveryDays,
        'allow_pickup': allowPickup,
        'pickup_address': allowPickup ? pickupAddress : null,
        'rates': {
          for (final r in rates)
            if (r.enabled) r.governorate: {'enabled': true, 'fee': r.fee ?? 0},
        },
      };
}

class StoreShippingService {
  final ApiClient _api = ApiClient();

  Future<StoreShippingSettings> load() async {
    final data = await _api.get('/seller/shipping');
    return StoreShippingSettings.fromJson(Map<String, dynamic>.from(data));
  }

  Future<StoreShippingSettings> save(StoreShippingSettings settings) async {
    final data = await _api.put('/seller/shipping', body: settings.toJson());
    return StoreShippingSettings.fromJson(Map<String, dynamic>.from(data));
  }
}
