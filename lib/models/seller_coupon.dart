/// كوبون أنشأه البائع لمتجره (المبالغ بالليرة كما يعيدها الخادم).
class SellerCoupon {
  const SellerCoupon({
    required this.id,
    required this.title,
    required this.type,
    required this.value,
    required this.valueLabel,
    this.maxDiscount,
    this.minOrderAmount = 0,
    required this.scope,
    required this.audience,
    this.autoFollowers = false,
    this.startsAt,
    this.endsAt,
    this.validDays,
    this.perCustomerLimit = 1,
    this.totalLimit,
    this.issuedCount = 0,
    this.redeemedCount = 0,
    required this.status,
    required this.statusLabel,
    this.reviewNote,
    this.isLocked = false,
    this.isRunning = false,
    this.buyProductId,
    this.giftProductId,
    this.productIds = const [],
  });

  final int id;
  final String title;

  /// percentage | fixed | free_shipping | gift
  final String type;
  final num value;
  final String valueLabel;
  final num? maxDiscount;
  final num minOrderAmount;

  /// all | products
  final String scope;

  /// collectable | followers
  final String audience;
  final bool autoFollowers;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final int? validDays;
  final int perCustomerLimit;
  final int? totalLimit;
  final int issuedCount;
  final int redeemedCount;

  /// pending_review | active | paused | suspended | rejected
  final String status;
  final String statusLabel;
  final String? reviewNote;

  /// جمعه عميل واحد على الأقل: يُسمح بالتمديد وزيادة العدد فقط، ولا يُحذف.
  final bool isLocked;
  final bool isRunning;
  final int? buyProductId;
  final int? giftProductId;
  final List<int> productIds;

  bool get canToggle => status == 'active' || status == 'paused';
  bool get canEdit => status != 'suspended' && status != 'rejected';
  bool get canDelete => !isLocked;

  static int? _int(dynamic v) => v is num ? v.toInt() : int.tryParse('$v');
  static num? _num(dynamic v) => v is num ? v : num.tryParse('${v ?? ''}');
  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v.toString())?.toLocal();

  factory SellerCoupon.fromJson(Map<String, dynamic> json) => SellerCoupon(
        id: _int(json['id']) ?? 0,
        title: '${json['title'] ?? ''}',
        type: '${json['type'] ?? 'percentage'}',
        value: _num(json['value']) ?? 0,
        valueLabel: '${json['value_label'] ?? ''}',
        maxDiscount: _num(json['max_discount']),
        minOrderAmount: _num(json['min_order_amount']) ?? 0,
        scope: '${json['scope'] ?? 'all'}',
        audience: '${json['audience'] ?? 'collectable'}',
        autoFollowers: json['auto_followers'] == true,
        startsAt: _date(json['starts_at']),
        endsAt: _date(json['ends_at']),
        validDays: _int(json['valid_days']),
        perCustomerLimit: _int(json['per_customer_limit']) ?? 1,
        totalLimit: _int(json['total_limit']),
        issuedCount: _int(json['issued_count']) ?? 0,
        redeemedCount: _int(json['redeemed_count']) ?? 0,
        status: '${json['status'] ?? 'active'}',
        statusLabel: '${json['status_label'] ?? json['status'] ?? ''}',
        reviewNote: json['review_note']?.toString(),
        isLocked: json['is_locked'] == true,
        isRunning: json['is_running'] == true,
        buyProductId: _int(json['buy_product_id']),
        giftProductId: _int(json['gift_product_id']),
        productIds: (json['product_ids'] as List? ?? const [])
            .map(_int)
            .whereType<int>()
            .toList(),
      );
}

/// منتج من متجر البائع يظهر في نموذج الكوبون.
class CouponProductOption {
  const CouponProductOption({
    required this.id,
    required this.name,
    this.hasVariants = false,
  });

  final int id;
  final String name;
  final bool hasVariants;

  factory CouponProductOption.fromJson(Map<String, dynamic> json) =>
      CouponProductOption(
        id: (json['id'] as num).toInt(),
        name: '${json['name'] ?? ''}',
        hasVariants: json['has_variants'] == true,
      );
}

/// صفحة «كوبوناتي»: القائمة + ما يحتاجه نموذج الإنشاء.
class SellerCouponsPage {
  const SellerCouponsPage({
    required this.coupons,
    this.blockReason,
    this.products = const [],
    this.maxPercent = 70,
    this.reviewAbovePercent = 50,
    this.followersCount = 0,
  });

  final List<SellerCoupon> coupons;

  /// سبب منع إنشاء كوبونات (متجر غير موثّق أو موقوف)، أو null.
  final String? blockReason;
  final List<CouponProductOption> products;
  final int maxPercent;
  final int reviewAbovePercent;
  final int followersCount;

  factory SellerCouponsPage.fromJson(Map<String, dynamic> json) =>
      SellerCouponsPage(
        coupons: (json['data'] as List? ?? const [])
            .whereType<Map>()
            .map((c) => SellerCoupon.fromJson(Map<String, dynamic>.from(c)))
            .toList(),
        blockReason: json['block_reason']?.toString(),
        products: (json['products'] as List? ?? const [])
            .whereType<Map>()
            .map((p) =>
                CouponProductOption.fromJson(Map<String, dynamic>.from(p)))
            .toList(),
        maxPercent: (json['max_percent'] as num?)?.toInt() ?? 70,
        reviewAbovePercent:
            (json['review_above_percent'] as num?)?.toInt() ?? 50,
        followersCount: (json['followers_count'] as num?)?.toInt() ?? 0,
      );
}
