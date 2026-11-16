int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

bool _toBool(dynamic value, [bool fallback = false]) {
  if (value == null) return fallback;
  if (value is bool) return value;
  final s = value.toString().toLowerCase().trim();
  if (s == '1' || s == 'true') return true;
  if (s == '0' || s == 'false') return false;
  return fallback;
}

class OrderItem {
  final int id;
  final int? productId;
  final String productName;
  final String? vendorName;
  final String? orderNumber;
  final String? orderStatus;
  final double unitPrice;
  final double? originalUnitPrice;
  final bool hasDealPrice;
  final int? dealDiscountPercentage;
  final int quantity;
  final double subtotal;
  final bool canBeReviewed;
  final bool? hasReview;

  /// بند هدية من كوبون المتجر (سعره 0)
  final bool isGift;

  /// الاسم للعرض مع علامة الهدية
  String get displayName => isGift ? '$productName (هدية)' : productName;

  /// رقم الطلب (في قائمة طلبات البائع؛ id هو رقم المنتج داخل الطلب)
  final int? orderId;

  /// الحالات التي يسمح الخادم للبائع بنقل الطلب إليها الآن
  final List<String>? nextStatuses;

  OrderItem({
    required this.id,
    this.productId,
    required this.productName,
    this.vendorName,
    this.orderNumber,
    this.orderStatus,
    required this.unitPrice,
    this.originalUnitPrice,
    this.hasDealPrice = false,
    this.dealDiscountPercentage,
    required this.quantity,
    required this.subtotal,
    required this.canBeReviewed,
    this.hasReview,
    this.isGift = false,
    this.orderId,
    this.nextStatuses,
  });

  factory OrderItem.fromJson(Map<String, dynamic> json) {
    double? d(dynamic v) => v == null ? null : _toDouble(v);
    return OrderItem(
      id: _toInt(json['id']) ?? 0,
      productId: _toInt(json['product_id']),
      productName: json['product_name']?.toString() ?? '',
      isGift: _toBool(json['is_gift']),
      vendorName: json['vendor_name']?.toString(),
      orderNumber: json['order_number']?.toString(),
      orderStatus: json['order_status']?.toString(),
      unitPrice: _toDouble(json['unit_price']),
      originalUnitPrice: d(json['original_unit_price']),
      hasDealPrice: _toBool(json['has_deal_price']),
      dealDiscountPercentage: _toInt(json['deal_discount_percentage']),
      quantity: _toInt(json['quantity']) ?? 0,
      subtotal: _toDouble(json['subtotal']),
      canBeReviewed: _toBool(json['can_be_reviewed']),
      hasReview:
          json['has_review'] == null ? null : _toBool(json['has_review']),
      orderId: _toInt(json['order_id']),
      nextStatuses: json['next_statuses'] is List
          ? (json['next_statuses'] as List).map((e) => e.toString()).toList()
          : null,
    );
  }
}

class Shipment {
  final int? id;
  final int? sellerProfileId;
  final String? sellerName;
  final String status;
  final String? trackingNumber;
  final String? shippingCompany;
  final DateTime? shippedAt;
  final DateTime? deliveredAt;

  Shipment({
    this.id,
    this.sellerProfileId,
    this.sellerName,
    required this.status,
    this.trackingNumber,
    this.shippingCompany,
    this.shippedAt,
    this.deliveredAt,
  });

  static const Map<String, String> statusLabels = {
    'pending': 'بانتظار الشحن',
    'shipped': 'تم الشحن',
    'in_transit': 'في الطريق',
    'delivered': 'تم التسليم',
    'returned': 'مرتجع',
  };

  String get statusLabel => statusLabels[status] ?? status;

  factory Shipment.fromJson(Map<String, dynamic> json) {
    return Shipment(
      id: _toInt(json['id']),
      sellerProfileId: _toInt(json['seller_profile_id']),
      sellerName: json['seller_name']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      trackingNumber: json['tracking_number']?.toString(),
      shippingCompany: json['shipping_company']?.toString(),
      shippedAt: json['shipped_at'] != null
          ? DateTime.tryParse(json['shipped_at'].toString())
          : null,
      deliveredAt: json['delivered_at'] != null
          ? DateTime.tryParse(json['delivered_at'].toString())
          : null,
    );
  }
}

class Order {
  final int id;
  final String orderNumber;
  final String status;
  final DateTime? archivedAt;
  final double subtotal;
  final double shippingFee;
  final double discountAmount;
  final double total;
  final String shippingName;
  final String shippingPhone;
  final String shippingAddress;
  final int? itemsCount;
  final bool canBeCancelled;
  final List<OrderItem> items;
  final String? paymentStatus;

  /// طريقة الدفع التي اختارها العميل: cash_on_delivery | card | wallet
  final String? paymentMethod;
  final List<Shipment> shipments;
  final DateTime? createdAt;

  Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.archivedAt,
    required this.subtotal,
    required this.shippingFee,
    required this.discountAmount,
    required this.total,
    required this.shippingName,
    required this.shippingPhone,
    required this.shippingAddress,
    this.itemsCount,
    required this.canBeCancelled,
    this.items = const [],
    this.paymentStatus,
    this.paymentMethod,
    this.shipments = const [],
    this.createdAt,
  });

  static const Map<String, String> statusLabels = {
    'pending': 'قيد المراجعة',
    'paid': 'مدفوع',
    'processing': 'قيد التجهيز',
    'shipped': 'تم الشحن',
    'delivered': 'تم التسليم',
    'cancelled': 'ملغي',
  };

  String get statusLabel => statusLabels[status] ?? status;

  int get effectiveItemsCount {
    if (items.isNotEmpty) return items.length;
    if (itemsCount != null && itemsCount! > 0) return itemsCount!;
    return 0;
  }

  String? get shipmentStatus =>
      shipments.isNotEmpty ? shipments.first.status : null;
  String? get trackingNumber =>
      shipments.isNotEmpty ? shipments.first.trackingNumber : null;
  String? get shippingCompany =>
      shipments.isNotEmpty ? shipments.first.shippingCompany : null;

  bool get isPaid => (paymentStatus ?? '').toLowerCase() == 'paid';

  /// الطلب بانتظار دفع إلكتروني (العميل اختار البطاقة ولم يكتمل الدفع بعد)
  bool get awaitsOnlinePayment =>
      paymentMethod == 'card' && !isPaid && status != 'cancelled';
  bool get isPaymentFailed {
    final s = (paymentStatus ?? '').toLowerCase();
    return s == 'failed' || s == 'cancelled';
  }

  String get paymentStatusLabel {
    switch ((paymentStatus ?? 'none').toLowerCase()) {
      case 'paid':
        return 'مدفوع';
      case 'failed':
        return 'فشل الدفع';
      case 'cancelled':
        return 'ملغي';
      case 'pending':
      case 'none':
      case '':
        return 'غير مدفوع';
      default:
        return paymentStatus ?? 'غير مدفوع';
    }
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    final payment = json['payment'] is Map
        ? Map<String, dynamic>.from(json['payment'] as Map)
        : null;

    final shipments = <Shipment>[];
    if (json['shipments'] is List) {
      for (final s in json['shipments'] as List) {
        if (s is Map) {
          shipments.add(Shipment.fromJson(Map<String, dynamic>.from(s)));
        }
      }
    }
    if (shipments.isEmpty && json['shipment'] is Map) {
      shipments.add(Shipment.fromJson(
          Map<String, dynamic>.from(json['shipment'] as Map)));
    }

    return Order(
      id: _toInt(json['id']) ?? 0,
      orderNumber: json['order_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      archivedAt: json['archived_at'] != null
          ? DateTime.tryParse(json['archived_at'].toString())
          : null,
      subtotal: _toDouble(json['subtotal']),
      shippingFee: _toDouble(json['shipping_fee']),
      discountAmount: _toDouble(json['discount_amount']),
      total: _toDouble(json['total']),
      shippingName: json['shipping_name']?.toString() ?? '',
      shippingPhone: json['shipping_phone']?.toString() ?? '',
      shippingAddress: json['shipping_address']?.toString() ?? '',
      itemsCount:
          _toInt(json['items_count'] ?? json['total_items'] ?? json['count']),
      canBeCancelled: _toBool(json['can_be_cancelled']),
      items: (json['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((i) => OrderItem.fromJson(Map<String, dynamic>.from(i)))
          .toList(),
      paymentStatus:
          json['payment_status']?.toString() ?? payment?['status']?.toString(),
      paymentMethod:
          json['payment_method']?.toString() ?? payment?['method']?.toString(),
      shipments: shipments,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
