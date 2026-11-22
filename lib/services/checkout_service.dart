import 'dart:typed_data';

import '../models/order.dart';
import '../models/wallet_coupon.dart';
import 'api_client.dart';
import 'loyalty_service.dart';

/// طرد متجر واحد في الطلب: من يوصله، وأجرته، ومتى يصل.
class CheckoutParcel {
  final int vendorId;
  final String storeName;
  final double fee;

  /// platform عبر شركة الشحن | self المتجر يوصل بنفسه | pickup استلام من محل المتجر
  final String mode;
  final String modeLabel;
  final String etaLabel;
  final bool canPickup;
  final String? pickupAddress;

  const CheckoutParcel({
    required this.vendorId,
    required this.storeName,
    required this.fee,
    this.mode = 'platform',
    this.modeLabel = '',
    this.etaLabel = '',
    this.canPickup = false,
    this.pickupAddress,
  });

  factory CheckoutParcel.fromJson(Map<String, dynamic> json) => CheckoutParcel(
        vendorId: int.tryParse('${json['vendor_id'] ?? 0}') ?? 0,
        storeName: json['store_name']?.toString() ?? '',
        fee: double.tryParse('${json['fee'] ?? 0}') ?? 0,
        mode: json['mode']?.toString() ?? 'platform',
        modeLabel: json['mode_label']?.toString() ?? '',
        etaLabel: json['eta_label']?.toString() ?? '',
        canPickup: json['can_pickup'] == true,
        pickupAddress: json['pickup_address']?.toString(),
      );
}

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

  /// رصيد بطاقات الهدايا المتاح (بالليرة)
  final double giftBalance;

  /// طريقة الاستلام التي حُسبت لها الأجرة: home | center
  final String deliveryMethod;

  /// أجرة الشحن بعد الكوبون لكل طريقة استلام
  final Map<String, double> shippingByMethod;

  /// عدد الطرود (طرد لكل متجر) وهل فيها طرد ثقيل (10 كغ فأكثر)
  final int parcelCount;
  final bool hasHeavyParcel;

  /// أجرة طلب رفض الزبون استلامه سابقاً، تُضاف لهذا الطلب
  final double shippingDebt;

  /// طرد لكل متجر بطريقة شحنه وأجرته ومدة وصوله
  final List<CheckoutParcel> parcels;

  /// محافظة الزبون التي حُسبت عليها الأجرة (أو خمّنها الخادم من العنوان)، وقائمة المحافظات
  final String? shippingGovernorate;
  final List<String> governorates;

  /// الدفع عند الاستلام ممنوع مؤقتاً بعد رفض استلام طلب
  final bool codBlocked;
  final String? codBlockedMessage;

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
    this.giftBalance = 0,
    this.deliveryMethod = 'home',
    this.shippingByMethod = const {},
    this.parcelCount = 1,
    this.hasHeavyParcel = false,
    this.shippingDebt = 0,
    this.parcels = const [],
    this.shippingGovernorate,
    this.governorates = const [],
    this.codBlocked = false,
    this.codBlockedMessage,
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
      giftBalance: d(json['gift_balance']),
      deliveryMethod: json['delivery_method']?.toString() ?? 'home',
      shippingByMethod: json['shipping_by_method'] is Map
          ? (json['shipping_by_method'] as Map)
              .map((k, v) => MapEntry(k.toString(), d(v)))
          : const {},
      parcelCount:
          json['parcels'] is List ? (json['parcels'] as List).length : 1,
      hasHeavyParcel: json['parcels'] is List &&
          (json['parcels'] as List).any((p) => p is Map && p['heavy'] == true),
      shippingDebt: d(json['shipping_debt']),
      parcels: json['parcels'] is List
          ? (json['parcels'] as List)
              .whereType<Map>()
              .map((m) => CheckoutParcel.fromJson(Map<String, dynamic>.from(m)))
              .toList()
          : const [],
      shippingGovernorate: json['shipping_governorate']?.toString(),
      governorates: json['governorates'] is List
          ? (json['governorates'] as List).map((g) => g.toString()).toList()
          : const [],
      codBlocked: json['cod_blocked'] == true,
      codBlockedMessage: json['cod_blocked_message']?.toString(),
    );
  }
}

class CheckoutService {
  final ApiClient _api = ApiClient();

  /// couponId: null = أفضل كوبون تلقائياً، 0 = بلا كوبون، رقم = كوبون من المحفظة
  /// governorate: محافظة الزبون (أسعار المتاجر التي توصل بنفسها)؛ إن غابت يخمّنها الخادم من shippingAddress.
  /// pickupStores: متاجر يستلم الزبون طردها من محلها.
  Future<CheckoutSummary> summary({
    int? couponId,
    String deliveryMethod = 'home',
    String? governorate,
    String? shippingAddress,
    Set<int> pickupStores = const {},
  }) async {
    final stores = pickupStores.toList();
    final data = await _api.get('/checkout/summary', query: {
      'delivery_method': deliveryMethod,
      if (couponId != null) 'customer_coupon_id': couponId,
      if (governorate != null) 'shipping_governorate': governorate,
      if (governorate == null && (shippingAddress ?? '').trim().isNotEmpty)
        'shipping_address': shippingAddress,
      for (var i = 0; i < stores.length; i++) 'pickup_stores[$i]': stores[i],
    });
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
    bool useGiftBalance = false,
    String deliveryMethod = 'home',
    int? pickupCenterId,
    String? governorate,
    Set<int> pickupStores = const {},
  }) async {
    final data = await _api.post('/checkout', body: {
      'shipping_name': shippingName,
      'shipping_phone': shippingPhone,
      // الاستلام من مركز لا يحتاج عنواناً (الخادم يكتب عنوان المركز)
      if (deliveryMethod == 'home') 'shipping_address': shippingAddress,
      'delivery_method': deliveryMethod,
      if (deliveryMethod == 'center') 'pickup_center_id': pickupCenterId,
      if (governorate != null) 'shipping_governorate': governorate,
      if (pickupStores.isNotEmpty) 'pickup_stores': pickupStores.toList(),
      'payment_method': paymentMethod,
      // غائب = الأفضل تلقائياً (يُعاد التحقق في الخادم)
      if (couponId != null) 'customer_coupon_id': couponId,
      // نقاط الولاء كخصم (يُعاد التحقق والقص في الخادم)
      if (usePoints > 0) 'use_points': usePoints,
      // رصيد بطاقات الهدايا يغطي ما تبقّى (يُحسب في الخادم)
      if (useGiftBalance) 'use_gift_balance': true,
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

  /// إلغاء طرد متجر واحد من الطلب ما دام «قيد المراجعة»
  Future<Order> cancelParcel(int orderId, int parcelId) async {
    final data = await _api.post('/orders/$orderId/parcels/$parcelId/cancel');
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
