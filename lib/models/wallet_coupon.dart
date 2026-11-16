/// كوبون في محفظة العميل (بلا رموز). المبالغ بالليرة.
class WalletCoupon {
  final int id;
  final String title;
  final String type; // percentage | fixed | free_shipping | gift
  final String valueLabel;
  final String? sourceLabel;
  final String funder; // platform | seller
  final double minOrderAmount;
  final String status; // available | used | expired
  final DateTime? expiresAt;
  final DateTime? usedAt;

  /// في سياق السلة فقط: هل ينطبق؟ لماذا لا؟ كم يوفّر؟
  final bool? ok;
  final String? reason;
  final int? saving;

  const WalletCoupon({
    required this.id,
    required this.title,
    required this.type,
    required this.valueLabel,
    this.sourceLabel,
    this.funder = 'platform',
    this.minOrderAmount = 0,
    this.status = 'available',
    this.expiresAt,
    this.usedAt,
    this.ok,
    this.reason,
    this.saving,
  });

  bool get isSeller => funder == 'seller';
  bool get isFreeShipping => type == 'free_shipping';

  /// ينتهي خلال أقل من 3 أيام (لعرض تنبيه)
  bool get expiresSoon =>
      expiresAt != null &&
      expiresAt!.difference(DateTime.now()).inHours < 72 &&
      expiresAt!.isAfter(DateTime.now());

  factory WalletCoupon.fromJson(Map<String, dynamic> json) {
    int? i(dynamic v) =>
        v == null ? null : int.tryParse(v.toString().split('.').first);
    return WalletCoupon(
      id: i(json['id']) ?? 0,
      title: json['title']?.toString() ?? '',
      type: json['type']?.toString() ?? 'fixed',
      valueLabel: json['value_label']?.toString() ?? '',
      sourceLabel: json['source_label']?.toString(),
      funder: json['funder']?.toString() ?? 'platform',
      minOrderAmount: double.tryParse('${json['min_order_amount'] ?? 0}') ?? 0,
      status: json['status']?.toString() ?? 'available',
      expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      usedAt: DateTime.tryParse(json['used_at']?.toString() ?? ''),
      ok: json['ok'] is bool ? json['ok'] as bool : null,
      reason: json['reason']?.toString(),
      saving: i(json['saving']),
    );
  }
}
