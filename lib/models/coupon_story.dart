import '../config/api_config.dart';

class CouponModel {
  final int id;
  final String code;
  final String type;
  final double value;
  final double minOrderAmount;
  final int? usageLimit;
  final int usedCount;
  final DateTime? expiresAt;
  final bool isActive;

  CouponModel({
    required this.id,
    required this.code,
    required this.type,
    required this.value,
    required this.minOrderAmount,
    this.usageLimit,
    required this.usedCount,
    this.expiresAt,
    required this.isActive,
  });

  String get valueLabel => type == 'percentage'
      ? '${value.toStringAsFixed(0)}%'
      : '${value.toStringAsFixed(0)} ل.س';

  factory CouponModel.fromJson(Map<String, dynamic> json) {
    return CouponModel(
      id: json['id'],
      code: json['code'],
      type: json['type'],
      value: double.tryParse(json['value'].toString()) ?? 0,
      minOrderAmount: double.tryParse(json['min_order_amount'].toString()) ?? 0,
      usageLimit: json['usage_limit'],
      usedCount: json['used_count'] ?? 0,
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'])
          : null,
      isActive: json['is_active'] ?? true,
    );
  }
}

class StoryModel {
  final int id;
  final String image;
  final String? caption;
  final bool isFromPlatform;
  final String? vendorName;
  final double? amountPaid;
  final bool isActive;
  final bool isExpired;
  final DateTime? expiresAt;

  StoryModel({
    required this.id,
    required this.image,
    this.caption,
    required this.isFromPlatform,
    this.vendorName,
    this.amountPaid,
    required this.isActive,
    required this.isExpired,
    this.expiresAt,
  });

  String get imageUrl {
    if (image.isEmpty) return '';
    final uri = Uri.tryParse(image);
    if (uri != null && uri.hasAuthority) {
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        final storagePath = uri.path.split('/storage/').last;
        return '${ApiConfig.storageBaseUrl}/storage/$storagePath';
      }

      return image;
    }

    final cleanPath = image.startsWith('/') ? image : '/$image';
    return '${ApiConfig.storageBaseUrl}$cleanPath';
  }

  factory StoryModel.fromJson(Map<String, dynamic> json) {
    final expiresAt = json['expires_at'] == null
        ? null
        : DateTime.tryParse(json['expires_at'].toString());
    final isActive = switch (json['is_active']) {
      false || 0 || '0' || 'false' => false,
      _ => true,
    };
    final isExpired = expiresAt != null
        ? !expiresAt.isAfter(DateTime.now())
        : json['is_expired'] == true || json['is_expired'] == 1;
    final vendor = json['vendor'];

    return StoryModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      image: (json['image'] ?? json['image_url'] ?? json['photo'] ?? '')
          .toString(),
      caption: json['caption']?.toString(),
      isFromPlatform:
          json['is_from_platform'] == 1 || json['is_from_platform'] == true,
      vendorName: json['vendor_name'] ??
          json['store_name'] ??
          (vendor is Map ? vendor['store_name'] : null) ??
          'تريند شام',
      amountPaid: json['amount_paid'] != null
          ? double.tryParse(json['amount_paid'].toString())
          : null,
      isActive: isActive,
      isExpired: isExpired,
      expiresAt: expiresAt,
    );
  }
}
