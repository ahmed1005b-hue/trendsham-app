import 'dart:typed_data';

import '../models/order.dart';
import '../models/wallet_coupon.dart';
import 'api_client.dart';
import 'loyalty_service.dart';

class CheckoutSummary {
  final double subtotal;
  final double shippingFee;
  final double discount;
  final double total;
  final bool couponValid;
  final String currency;
  final String? pricingNote;

  /// رسم الشحن قبل كوبون الشحن المجاني
  final double baseShippingFee;

  /// الكوبون المطبّق (null = بلا كوبون)، وهل اختاره النظام تلقائياً
  final WalletCoupon? coupon;
  final bool couponAuto;

  /// كل كوبونات المحفظة مع صلاحيتها لهذه السلة
  final List<WalletCoupon> couponOptions;

  /// لماذا سقط الكوبون الذي اختاره العميل (إن سقط)
  final String? couponDroppedReason;

  /// نقاط الولاء: الرصيد وأقصى ما يُستخدم وكم سيكسب
  final CheckoutLoyalty? loyalty;

  const CheckoutSummary({
    required this.subtotal,
    required this.shippingFee,
    required this.discount,
    required this.total,
    required this.couponValid,
    required this.currency,
    this.pricingNote,
    this.baseShippingFee = 0,
    this.coupon,
    this.couponAuto = false,
    this.couponOptions = const [],
    this.couponDroppedReason,
    this.loyalty,
  });

  factory CheckoutSummary.fromJson(Map<String, dynamic> json) {
    double d(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;
    return CheckoutSummary(
      subtotal: d(json['subtotal']),
      shippingFee: d(json['shipping_fee']),
      discount: d(json['discount']),
      total: d(json['total']),
      couponValid: json['coupon'] is Map || json['coupon_valid'] == true,
      baseShippingFee: d(json['base_shipping_fee'] ?? json['shipping_fee']),
      coupon: json['coupon'] is Map
          ? WalletCoupon.fromJson(Map<String, dynamic>.from(json['coupon']))
          : null,
      couponAuto: json['coupon_auto'] == true,
      couponDroppedReason: json['coupon_dropped_reason']?.toString(),
      couponOptions: (json['coupon_options'] is List)
          ? (json['coupon_options'] as List)
              .whereType<Map>()
              .map((m) => WalletCoupon.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      currency: (json['currency']?.toString() ?? 'SYP') == 'SYP'
          ? 'ل.س'
          : (json['currency']?.toString() ?? 'ل.س'),
      pricingNote: json['pricing_note']?.toString(),
      loyalty: json['loyalty'] is Map
          ? CheckoutLoyalty.fromJson(Map<String, dynamic>.from(json['loyalty']))
          : null,
    );
  }
}

class CheckoutService {
  final ApiClient _api = ApiClient();

  /// couponId: null = أفضل كوبون تلقائياً، 0 = بلا كوبون، رقم = كوبون من المحفظة
  Future<CheckoutSummary> summary({int? couponId}) async {
    final data = await _api.get('/checkout/summary',
        query: couponId == null ? null : {'customer_coupon_id': couponId});
    if (data is! Map) {
      throw const FormatException('استجابة ملخص الدفع غير صالحة.');
    }
    return CheckoutSummary.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Order> placeOrder({
    required String shippingName,
    required String shippingPhone,
    required String shippingAddress,
    required String paymentMethod,
    int? couponId,
    int usePoints = 0,
  }) async {
    final data = await _api.post('/checkout', body: {
      'shipping_name': shippingName,
      'shipping_phone': shippingPhone,
      'shipping_address': shippingAddress,
      'payment_method': paymentMethod,
      // غائب = الأفضل تلقائياً (يُعاد التحقق في الخادم)
      if (couponId != null) 'customer_coupon_id': couponId,
      // نقاط الولاء كخصم (يُعاد التحقق والقص في الخادم)
      if (usePoints > 0) 'use_points': usePoints,
    });

    return Order.fromJson(data['data'] ?? data);
  }
}

class OrderService {
  final ApiClient _api = ApiClient();

  Future<List<Order>> list() async {
    final data = await _api.get('/orders');
    return (data['data'] as List).map((o) => Order.fromJson(o)).toList();
  }

  Future<Order> show(int id) async {
    final data = await _api.get('/orders/$id');
    return Order.fromJson(data['data'] ?? data);
  }

  Future<Order> cancel(int id) async {
    final data = await _api.post('/orders/$id/cancel');
    return Order.fromJson(data['data'] ?? data);
  }

  /// فاتورة الطلب PDF
  Future<Uint8List> invoice(int id) => _api.getBytes('/orders/$id/invoice');

  Future<void> submitReview(int orderItemId,
      {required int rating, String? comment}) async {
    await _api.post('/order-items/$orderItemId/review', body: {
      'rating': rating,
      'comment': comment,
    });
  }
}

/// محفظة الكوبونات
class CouponService {
  final ApiClient _api = ApiClient();

  /// tab: available | used | expired
  Future<List<WalletCoupon>> myCoupons({String tab = 'available'}) async {
    final data = await _api.get('/coupons', query: {'tab': tab});
    final list =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    return list
        .whereType<Map>()
        .map((m) => WalletCoupon.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }
}
