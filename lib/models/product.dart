import 'store_coupon.dart';
import 'category.dart';
import 'vendor.dart';

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

class ActiveDailyDeal {
  final int? id;
  final double? discountedPrice;
  final double? specialPrice;
  final int? discountPercentage;
  final DateTime? endsAt;
  final String? remainingTime;

  const ActiveDailyDeal({
    this.id,
    this.discountedPrice,
    this.specialPrice,
    this.discountPercentage,
    this.endsAt,
    this.remainingTime,
  });

  factory ActiveDailyDeal.fromJson(Map<String, dynamic> json) {
    double? parsePrice(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    return ActiveDailyDeal(
      id: (json['id'] as num?)?.toInt(),
      discountedPrice:
          parsePrice(json['discounted_price']) ?? parsePrice(json['effective_price']),
      specialPrice: parsePrice(json['special_price']),
      discountPercentage: _toInt(json['discount_percentage']),
      endsAt: json['ends_at'] != null
          ? DateTime.tryParse(json['ends_at'].toString())
          : null,
      remainingTime: json['remaining_time']?.toString(),
    );
  }
}

class ProductVariant {
  final int id;
  final String? color;
  final String? colorName;
  final String? colorHex;
  final String? size;
  final String? sku;
  final double priceAdjustment;
  final double effectivePrice;
  final int stockQuantity;
  final bool isActive;
  final String label;

  const ProductVariant({
    required this.id,
    this.color,
    this.colorName,
    this.colorHex,
    this.size,
    this.sku,
    this.priceAdjustment = 0,
    this.effectivePrice = 0,
    this.stockQuantity = 0,
    this.isActive = true,
    this.label = '',
  });

  factory ProductVariant.fromJson(Map<String, dynamic> json) {
    return ProductVariant(
      id: _toInt(json['id']) ?? 0,
      color: json['color']?.toString(),
      colorName: json['color_name']?.toString(),
      colorHex: json['color_hex']?.toString(),
      size: json['size']?.toString(),
      sku: json['sku']?.toString(),
      priceAdjustment: double.tryParse(json['price_adjustment']?.toString() ?? '0') ?? 0,
      effectivePrice: double.tryParse(json['effective_price']?.toString() ?? '0') ?? 0,
      stockQuantity: _toInt(json['stock_quantity']) ?? 0,
      isActive: json['is_active'] != false,
      label: json['label']?.toString() ?? '',
    );
  }
}

class Product {
  final int id;
  final String slug;
  final String name;
  final String? description;
  final String? sku;
  final double price;
  final double? compareAtPrice;
  final int? discountPercentage;
  final double? effectivePrice;
  final String? formattedEffectivePrice;
  final double? dealDiscountedPrice;
  final int? dealDiscountPercentage;
  final String? dealLabel;
  final DateTime? dealEndsAt;
  final int stockQuantity;

  /// وزن القطعة بالغرام (للشحن)، null إن لم يحدده البائع
  final int? weightGrams;
  final String? status;

  /// للبائع صاحب المنتج فقط: هل وافقت الإدارة، وسبب الرفض إن رُفض
  final bool? adminApproved;
  final String? rejectionNote;
  final bool inStock;
  final double? averageRating;
  final int reviewsCount;
  final Category? category;
  final Vendor? vendor;
  final List<ProductImage> images;
  final ProductImage? primaryImage;
  final List<ProductVariant> variants;
  final bool isFavorited;

  /// نقاط الولاء المتوقعة لشراء قطعة (من صفحة المنتج فقط)
  final int willEarnPoints;

  /// كوبونات متجر المنتج التي تشمله (من تفاصيل المنتج فقط)
  final List<StoreCoupon> storeCoupons;
  final int viewsCount;
  final int salesCount;

  Product({
    required this.id,
    required this.slug,
    required this.name,
    this.description,
    this.sku,
    required this.price,
    this.compareAtPrice,
    this.discountPercentage,
    this.effectivePrice,
    this.formattedEffectivePrice,
    this.dealDiscountedPrice,
    this.dealDiscountPercentage,
    this.dealLabel,
    this.dealEndsAt,
    required this.stockQuantity,
    this.weightGrams,
    this.status,
    this.adminApproved,
    this.rejectionNote,
    required this.inStock,
    this.averageRating,
    required this.reviewsCount,
    this.category,
    this.vendor,
    this.images = const [],
    this.primaryImage,
    this.variants = const [],
    this.isFavorited = false,
    this.willEarnPoints = 0,
    this.storeCoupons = const [],
    this.viewsCount = 0,
    this.salesCount = 0,
  });

  bool get hasActiveDeal =>
      displayPrice < price || ((dealDiscountPercentage ?? 0) > 0) || dealLabel != null;

  double get displayPrice => effectivePrice ?? dealDiscountedPrice ?? price;

  double? get displayCompareAtPrice {
    if (compareAtPrice != null && compareAtPrice! > displayPrice) {
      return compareAtPrice;
    }
    if (displayPrice < price) return price;
    return null;
  }

  int? get displayDiscountPercentage {
    final explicit = dealDiscountPercentage ?? discountPercentage;
    if (explicit != null && explicit > 0) return explicit;
    final original = displayCompareAtPrice;
    if (original != null && original > 0 && displayPrice < original) {
      return (((original - displayPrice) / original) * 100).round().clamp(1, 99);
    }
    return null;
  }

  String get formattedPrice =>
      formattedEffectivePrice ?? '${displayPrice.toStringAsFixed(0)} ل.س';
  String? get formattedCompareAtPrice => displayCompareAtPrice != null
      ? '${displayCompareAtPrice!.toStringAsFixed(0)} ل.س'
      : null;
  String get formattedOriginalPrice => '${price.toStringAsFixed(0)} ل.س';

  /// نسخة بعرض يومي مفروض عليها (من جدول daily_deals):
  /// السعر يصبح سعر العرض والسعر الأصلي يصبح compareAtPrice.
  Product copyWithManualDeal({
    required double dealPrice,
    int? dealPercentage,
    DateTime? dealEndsAt,
  }) {
    return Product(
      id: id,
      slug: slug,
      name: name,
      description: description,
      sku: sku,
      price: price,
      compareAtPrice: price > dealPrice ? price : compareAtPrice,
      discountPercentage: dealPercentage ?? discountPercentage,
      effectivePrice: dealPrice,
      formattedEffectivePrice: '${dealPrice.toStringAsFixed(0)} ل.س',
      dealDiscountedPrice: dealPrice,
      dealDiscountPercentage: dealPercentage ?? discountPercentage,
      dealLabel: 'عرض اليوم',
      dealEndsAt: dealEndsAt ?? this.dealEndsAt,
      stockQuantity: stockQuantity,
      status: status,
      inStock: inStock,
      averageRating: averageRating,
      reviewsCount: reviewsCount,
      category: category,
      vendor: vendor,
      images: images,
      primaryImage: primaryImage,
      isFavorited: isFavorited,
    );
  }



  Product copyWith({
    int? id,
    String? slug,
    String? name,
    String? description,
    String? sku,
    double? price,
    double? compareAtPrice,
    int? discountPercentage,
    double? effectivePrice,
    String? formattedEffectivePrice,
    double? dealDiscountedPrice,
    int? dealDiscountPercentage,
    String? dealLabel,
    DateTime? dealEndsAt,
    int? stockQuantity,
    String? status,
    bool? inStock,
    double? averageRating,
    int? reviewsCount,
    Category? category,
    Vendor? vendor,
    List<ProductImage>? images,
    ProductImage? primaryImage,
    List<ProductVariant>? variants,
    bool? isFavorited,
    int? willEarnPoints,
    List<StoreCoupon>? storeCoupons,
    int? viewsCount,
    int? salesCount,
  }) {
    return Product(
      id: id ?? this.id,
      slug: slug ?? this.slug,
      name: name ?? this.name,
      description: description ?? this.description,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      compareAtPrice: compareAtPrice ?? this.compareAtPrice,
      discountPercentage: discountPercentage ?? this.discountPercentage,
      effectivePrice: effectivePrice ?? this.effectivePrice,
      formattedEffectivePrice: formattedEffectivePrice ?? this.formattedEffectivePrice,
      dealDiscountedPrice: dealDiscountedPrice ?? this.dealDiscountedPrice,
      dealDiscountPercentage: dealDiscountPercentage ?? this.dealDiscountPercentage,
      dealLabel: dealLabel ?? this.dealLabel,
      dealEndsAt: dealEndsAt ?? this.dealEndsAt,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      weightGrams: weightGrams,
      status: status ?? this.status,
      adminApproved: adminApproved,
      rejectionNote: rejectionNote,
      inStock: inStock ?? this.inStock,
      averageRating: averageRating ?? this.averageRating,
      reviewsCount: reviewsCount ?? this.reviewsCount,
      category: category ?? this.category,
      vendor: vendor ?? this.vendor,
      images: images ?? this.images,
      primaryImage: primaryImage ?? this.primaryImage,
      variants: variants ?? this.variants,
      isFavorited: isFavorited ?? this.isFavorited,
      willEarnPoints: willEarnPoints ?? this.willEarnPoints,
      storeCoupons: storeCoupons ?? this.storeCoupons,
      viewsCount: viewsCount ?? this.viewsCount,
      salesCount: salesCount ?? this.salesCount,
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    double parseDouble(dynamic value, [double fallback = 0]) {
      return double.tryParse(value?.toString() ?? '') ?? fallback;
    }

    double? parseNullableDouble(dynamic value) {
      if (value == null) return null;
      return double.tryParse(value.toString());
    }

    ActiveDailyDeal? activeDeal;
    final rawDeal = json['active_daily_deal'] ?? json['daily_deal'] ?? json['deal'];
    if (rawDeal is Map) {
      activeDeal = ActiveDailyDeal.fromJson(Map<String, dynamic>.from(rawDeal));
    }

    final price = parseDouble(json['price']);
    final compareAtPrice = parseNullableDouble(json['compare_at_price']) ??
        parseNullableDouble(json['original_price']);
    final apiEffective = parseNullableDouble(json['discounted_price']) ??
        parseNullableDouble(json['effective_price']) ??
        activeDeal?.discountedPrice;
    final effectivePrice =
        apiEffective != null && apiEffective > 0 ? apiEffective : null;
    final discount = _toInt(json['discount_percentage']) ??
        _toInt(json['deal_discount_percentage']) ??
        activeDeal?.discountPercentage;

    final parsedImages = _parseImages(json);
    final parsedVariants = _parseVariants(json);
    final normalizedImages = parsedImages.isNotEmpty
        ? parsedImages
        : (json['primary_image'] is Map
            ? [
                ProductImage.fromJson(
                    Map<String, dynamic>.from(json['primary_image']))
              ]
            : <ProductImage>[]);
    final normalizedPrimary = json['primary_image'] is Map
        ? ProductImage.fromJson(
            Map<String, dynamic>.from(json['primary_image']))
        : (normalizedImages.isNotEmpty ? normalizedImages.first : null);

    return Product(
      id: _toInt(json['id']) ?? 0,
      slug: json['slug']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      sku: json['sku']?.toString(),
      price: price,
      compareAtPrice: compareAtPrice,
      discountPercentage: discount,
      effectivePrice: effectivePrice,
      formattedEffectivePrice: json['formatted_effective_price']?.toString(),
      dealDiscountedPrice: activeDeal?.discountedPrice ?? effectivePrice,
      dealDiscountPercentage: discount,
      dealLabel: json['deal_label']?.toString() ??
          ((effectivePrice != null && effectivePrice < price) || activeDeal != null
              ? 'عرض اليوم'
              : null),
      dealEndsAt: activeDeal?.endsAt,
      stockQuantity: _toInt(json['stock_quantity']) ?? 0,
      weightGrams: _toInt(json['weight_grams']),
      status: json['status']?.toString(),
      adminApproved: json['admin_approved'] is bool ? json['admin_approved'] as bool : null,
      rejectionNote: (json['rejection_note']?.toString().trim().isEmpty ?? true)
          ? null
          : json['rejection_note'].toString(),
      inStock: json['in_stock'] == true || (_toInt(json['stock_quantity']) ?? 0) > 0,
      averageRating: parseNullableDouble(json['average_rating']),
      reviewsCount: _toInt(json['reviews_count']) ?? 0,
      category: json['category'] is Map
          ? Category.fromJson(Map<String, dynamic>.from(json['category']))
          : null,
      vendor: json['vendor'] is Map
          ? Vendor.fromJson(Map<String, dynamic>.from(json['vendor']))
          : null,
      images: normalizedImages,
      primaryImage: normalizedPrimary,
      variants: parsedVariants,
      isFavorited: json['is_favorited'] == true,
      willEarnPoints: _toInt(json['will_earn_points']) ?? 0,
      storeCoupons: StoreCoupon.listFrom(json['store_coupons']),
      viewsCount: _toInt(json['views_count']) ?? _toInt(json['views']) ?? 0,
      salesCount: _toInt(json['sales_count']) ?? _toInt(json['sales']) ?? 0,
    );
  }

  static List<ProductImage> _parseImages(Map<String, dynamic> json) {
    final rawList = json['images'] ??
        json['image_urls'] ??
        json['all_images'] ??
        json['gallery'];
    if (rawList is! List) return [];
    final list = <ProductImage>[];
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is Map) {
        final map = Map<String, dynamic>.from(item);
        final url = (map['url'] ?? map['image_url'] ?? map['path'])?.toString();
        if (url != null && url.isNotEmpty) {
          list.add(ProductImage(
            id: _toInt(map['id']) ?? i,
            url: url,
            isPrimary: map['is_primary'] as bool? ?? (i == 0),
            color: map['color']?.toString(),
            colorName: map['color_name']?.toString(),
          ));
        }
      } else if (item is String && item.isNotEmpty) {
        list.add(ProductImage(
          id: i,
          url: item,
          isPrimary: i == 0,
        ));
      }
    }
    return list;
  }

  static List<ProductVariant> _parseVariants(Map<String, dynamic> json) {
    final rawList = json['variants'];
    if (rawList is! List) return [];
    return rawList
        .whereType<Map>()
        .map((m) => ProductVariant.fromJson(Map<String, dynamic>.from(m)))
        .where((v) => v.isActive)
        .toList();
  }
}
