/// كوبون متجر قابل للحفظ (يظهر في شاشة المتجر وتفاصيل المنتج). المبالغ بالليرة.
class StoreCoupon {
  final int id;
  final String title;
  final String type;
  final String valueLabel;
  final double minOrderAmount;
  final String? endsAt;
  final String scopeLabel;
  final int remaining;

  /// collectable | collected | sold_out | login_required
  final String state;

  const StoreCoupon({
    required this.id,
    required this.title,
    required this.type,
    required this.valueLabel,
    this.minOrderAmount = 0,
    this.endsAt,
    this.scopeLabel = '',
    this.remaining = 0,
    this.state = 'collectable',
  });

  factory StoreCoupon.fromJson(Map<String, dynamic> json) => StoreCoupon(
        id: (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        type: json['type']?.toString() ?? 'fixed',
        valueLabel: json['value_label']?.toString() ?? '',
        minOrderAmount: (json['min_order_amount'] as num?)?.toDouble() ?? 0,
        endsAt: json['ends_at']?.toString(),
        scopeLabel: json['scope_label']?.toString() ?? '',
        remaining: (json['remaining'] as num?)?.toInt() ?? 0,
        state: json['state']?.toString() ?? 'collectable',
      );

  static List<StoreCoupon> listFrom(dynamic source) {
    if (source is! List) return const [];
    return source
        .whereType<Map>()
        .map((e) => StoreCoupon.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  bool get canCollect => state == 'collectable' || state == 'login_required';

  StoreCoupon copyWith({String? state, int? remaining}) => StoreCoupon(
        id: id,
        title: title,
        type: type,
        valueLabel: valueLabel,
        minOrderAmount: minOrderAmount,
        endsAt: endsAt,
        scopeLabel: scopeLabel,
        remaining: remaining ?? this.remaining,
        state: state ?? this.state,
      );

  /// النص القصير في الجانب الملوّن من البطاقة
  String get shortValue => switch (type) {
        'free_shipping' => 'شحن مجاني',
        'gift' => 'هدية',
        _ => valueLabel.replaceFirst('خصم ', '').split(' حتى').first,
      };
}
