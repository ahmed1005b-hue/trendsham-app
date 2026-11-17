class ProductImage {
  final int id;
  final String url;

  /// نسخة صغيرة (عرض 600) للبطاقات والقوائم؛ الصفحة والتكبير يستعملان [url]
  final String? thumbUrl;
  final bool isPrimary;
  final String? color;
  final String? colorName;
  final String? colorHex;

  ProductImage({
    required this.id,
    required this.url,
    required this.isPrimary,
    this.thumbUrl,
    this.color,
    this.colorName,
    this.colorHex,
  });

  factory ProductImage.fromJson(Map<String, dynamic> json) {
    return ProductImage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      url: (json['url'] ?? json['image_url'] ?? json['path'])?.toString() ?? '',
      thumbUrl: json['thumb_url']?.toString(),
      isPrimary: json['is_primary'] as bool? ?? false,
      color: json['color'] ?? json['color_code'],
      colorName: json['color_name'],
      colorHex: json['color_hex']?.toString(),
    );
  }

  /// الرابط المناسب للقوائم: الصغير إن وُجد، وإلا الأصلي
  String get listUrl =>
      (thumbUrl != null && thumbUrl!.isNotEmpty) ? thumbUrl! : url;
}

class Vendor {
  final int id;
  final String storeName;
  final String? storeDescription;
  final String? storeLogo;
  final String? storeBanner;
  final String? storeContactPhone;
  final String? storeWhatsapp;
  final String? storeInstagram;
  final String? businessHours;
  final String? shippingPolicy;
  final String? returnPolicy;
  final String? storeUrl;
  final int? productsCount;
  final double? sellerRating;
  final int sellerReviewsCount;
  final bool isFollowed;
  final int followersCount;
  final Map<String, dynamic>? businessHoursStatus;

  Vendor({
    required this.id,
    required this.storeName,
    this.storeDescription,
    this.storeLogo,
    this.storeBanner,
    this.storeContactPhone,
    this.storeWhatsapp,
    this.storeInstagram,
    this.businessHours,
    this.shippingPolicy,
    this.returnPolicy,
    this.storeUrl,
    this.productsCount,
    this.sellerRating,
    this.sellerReviewsCount = 0,
    this.isFollowed = false,
    this.followersCount = 0,
    this.businessHoursStatus,
  });

  factory Vendor.fromJson(Map<String, dynamic> json) {
    return Vendor(
      id: json['id'],
      storeName: json['store_name'] ?? '',
      storeDescription: json['store_description'],
      storeLogo: json['store_logo'],
      storeBanner: json['store_banner'],
      storeContactPhone: json['store_contact_phone'],
      storeWhatsapp: json['store_whatsapp'],
      storeInstagram: json['store_instagram'],
      businessHours: json['business_hours'],
      shippingPolicy: json['shipping_policy'],
      returnPolicy: json['return_policy'],
      storeUrl: json['store_url'] ?? json['storeUrl'],
      productsCount: (json['products_count'] as num?)?.toInt(),
      sellerRating: (json['seller_rating'] as num?)?.toDouble(),
      sellerReviewsCount: (json['seller_reviews_count'] as num?)?.toInt() ?? 0,
      isFollowed: json['is_followed'] as bool? ?? false,
      followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      businessHoursStatus: json['business_hours_status'] is Map
          ? Map<String, dynamic>.from(json['business_hours_status'] as Map)
          : null,
    );
  }
}
