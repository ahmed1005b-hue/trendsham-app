/// طرد البائع في طلب واحد: كيف يُوصَّل، وكم يحصّل من الزبون، وما الخطوة التالية.
class SellerParcel {
  const SellerParcel({
    required this.status,
    this.statusLabel,
    this.deliveryMode = 'platform',
    this.deliveryModeLabel,
    this.sellerDelivers = false,
    this.codAmount = 0,
    this.shippingFee = 0,
    this.trackingNumber,
    this.governorate,
    this.isShared = false,
    this.nextStatuses = const [],
    this.canPrintLabel = false,
  });

  final String status;
  final String? statusLabel;

  /// platform = شركة الشحن، self = المتجر يوصل، pickup = الزبون يستلم من المحل
  final String deliveryMode;
  final String? deliveryModeLabel;
  final bool sellerDelivers;

  /// المبلغ الذي يُحصَّل من الزبون عند التسليم (بالليرة)
  final double codAmount;
  final double shippingFee;
  final String? trackingNumber;
  final String? governorate;

  /// في الطلب منتجات من متاجر أخرى
  final bool isShared;
  final List<String> nextStatuses;
  final bool canPrintLabel;

  bool get isPickup => deliveryMode == 'pickup';

  factory SellerParcel.fromJson(Map<String, dynamic> json) => SellerParcel(
        status: json['status']?.toString() ?? 'pending',
        statusLabel: json['status_label']?.toString(),
        deliveryMode: json['delivery_mode']?.toString() ?? 'platform',
        deliveryModeLabel: json['delivery_mode_label']?.toString(),
        sellerDelivers: json['seller_delivers'] == true,
        codAmount: (json['cod_amount'] as num?)?.toDouble() ?? 0,
        shippingFee: (json['shipping_fee'] as num?)?.toDouble() ?? 0,
        trackingNumber: json['tracking_number']?.toString(),
        governorate: json['shipping_governorate']?.toString(),
        isShared: json['is_shared'] == true,
        nextStatuses: (json['next_statuses'] as List? ?? const [])
            .map((s) => s.toString())
            .toList(),
        canPrintLabel: json['can_print_label'] == true,
      );
}
