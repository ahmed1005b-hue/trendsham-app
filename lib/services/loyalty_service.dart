import 'api_client.dart';

double _d(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;
int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

/// ملخص نقاط الولاء للعميل (GET /loyalty). المبالغ بالليرة.
class LoyaltySummary {
  final bool enabled;
  final int balance;
  final double balanceValue;
  final int pending;
  final int debt;
  final double pointValue;
  final double spendPerPoint;
  final int minRedeem;
  final int couponValidDays;
  final int expiringPoints;
  final String? expiringAt;

  const LoyaltySummary({
    required this.enabled,
    required this.balance,
    required this.balanceValue,
    required this.pending,
    required this.debt,
    required this.pointValue,
    required this.spendPerPoint,
    required this.minRedeem,
    required this.couponValidDays,
    this.expiringPoints = 0,
    this.expiringAt,
  });

  bool get canRedeem => enabled && balance >= minRedeem;

  factory LoyaltySummary.fromJson(Map<String, dynamic> j) {
    final soon = j['expiring_soon'];
    return LoyaltySummary(
      enabled: j['enabled'] != false,
      balance: _i(j['balance']),
      balanceValue: _d(j['balance_value']),
      pending: _i(j['pending']),
      debt: _i(j['debt']),
      pointValue: _d(j['point_value']),
      spendPerPoint: _d(j['spend_per_point']),
      minRedeem: _i(j['min_redeem']),
      couponValidDays: _i(j['coupon_valid_days']),
      expiringPoints: soon is Map ? _i(soon['points']) : 0,
      expiringAt: soon is Map ? soon['expires_at']?.toString() : null,
    );
  }
}

/// حركة في سجل النقاط
class LoyaltyTransaction {
  final int id;
  final String type;
  final String label;
  final int points;
  final String? orderNumber;
  final String? expiresAt;
  final DateTime? createdAt;

  const LoyaltyTransaction({
    required this.id,
    required this.type,
    required this.label,
    required this.points,
    this.orderNumber,
    this.expiresAt,
    this.createdAt,
  });

  factory LoyaltyTransaction.fromJson(Map<String, dynamic> j) =>
      LoyaltyTransaction(
        id: _i(j['id']),
        type: (j['type'] ?? '').toString(),
        label: (j['label'] ?? '').toString(),
        points: _i(j['points']),
        orderNumber: j['order_number']?.toString(),
        expiresAt: j['expires_at']?.toString(),
        createdAt: DateTime.tryParse((j['created_at'] ?? '').toString()),
      );
}

class LoyaltyPage {
  final List<LoyaltyTransaction> items;
  final int? nextPage;
  const LoyaltyPage(this.items, this.nextPage);

  factory LoyaltyPage.fromJson(Map<String, dynamic> j) => LoyaltyPage(
        (j['data'] is List ? j['data'] as List : const [])
            .whereType<Map>()
            .map((m) => LoyaltyTransaction.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
        j['next_page'] == null ? null : _i(j['next_page']),
      );
}

/// نتيجة تحويل النقاط إلى كوبون
class ConvertResult {
  final int couponId;
  final double value;
  final String expiresAt;
  final int balance;
  const ConvertResult(this.couponId, this.value, this.expiresAt, this.balance);

  factory ConvertResult.fromJson(Map<String, dynamic> j) => ConvertResult(
      _i(j['coupon_id']), _d(j['value']), (j['expires_at'] ?? '').toString(), _i(j['balance']));
}

/// معلومات النقاط في ملخص الدفع
class CheckoutLoyalty {
  final bool enabled;
  final int balance;
  final int maxUsable;
  final double pointValue;
  final int minRedeem;
  final int willEarn;
  final double spendPerPoint;

  const CheckoutLoyalty({
    required this.enabled,
    required this.balance,
    required this.maxUsable,
    required this.pointValue,
    required this.minRedeem,
    required this.willEarn,
    this.spendPerPoint = 10000,
  });

  bool get usable => enabled && maxUsable >= minRedeem && maxUsable > 0;

  factory CheckoutLoyalty.fromJson(Map<String, dynamic> j) => CheckoutLoyalty(
        enabled: j['enabled'] != false,
        balance: _i(j['balance']),
        maxUsable: _i(j['max_usable']),
        pointValue: _d(j['point_value']),
        minRedeem: _i(j['min_redeem']),
        willEarn: _i(j['will_earn']),
        spendPerPoint: _d(j['spend_per_point']) > 0 ? _d(j['spend_per_point']) : 10000,
      );
}

/// "نقطة واحدة / نقطتين / 5 نقاط / 12 نقطة"
String pointsLabel(int n) {
  if (n == 1) return 'نقطة واحدة';
  if (n == 2) return 'نقطتين';
  if (n >= 3 && n <= 10) return '$n نقاط';
  return '$n نقطة';
}

class LoyaltyService {
  final ApiClient _api = ApiClient();

  Future<LoyaltySummary> fetchSummary() async {
    final data = await _api.get('/loyalty');
    return LoyaltySummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<LoyaltyPage> fetchTransactions({int page = 1}) async {
    final data = await _api.get('/loyalty/transactions', query: {'page': page});
    return LoyaltyPage.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<ConvertResult> convert(int points) async {
    final data = await _api.post('/loyalty/convert', body: {'points': points});
    return ConvertResult.fromJson(Map<String, dynamic>.from(data as Map));
  }
}
