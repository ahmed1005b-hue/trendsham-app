import 'package:url_launcher/url_launcher.dart';

import 'api_client.dart';

double _d(dynamic v) => double.tryParse((v ?? 0).toString()) ?? 0;

/// بطاقة هدية اشتراها المستخدم. الكود يظهر فقط قبل استخدامها.
class GiftCard {
  final int id;
  final double amount;
  final String status;
  final String statusLabel;
  final String? code;
  final String? recipientName;
  final String? message;
  final String? expiresAt;
  final String? redeemedBy;
  final String? redeemedAt;

  const GiftCard({
    required this.id,
    required this.amount,
    required this.status,
    required this.statusLabel,
    this.code,
    this.recipientName,
    this.message,
    this.expiresAt,
    this.redeemedBy,
    this.redeemedAt,
  });

  bool get isActive => status == 'active' && code != null;
  bool get isFinal => status != 'pending_payment';

  factory GiftCard.fromJson(Map<String, dynamic> j) => GiftCard(
        id: int.tryParse('${j['id']}') ?? 0,
        amount: _d(j['amount']),
        status: (j['status'] ?? '').toString(),
        statusLabel: (j['status_label'] ?? '').toString(),
        code: j['code']?.toString(),
        recipientName: j['recipient_name']?.toString(),
        message: j['message']?.toString(),
        expiresAt: j['expires_at']?.toString(),
        redeemedBy: j['redeemed_by']?.toString(),
        redeemedAt: j['redeemed_at']?.toString(),
      );
}

class GiftBalanceMove {
  final String label;
  final double amount;
  final String date;

  const GiftBalanceMove(this.label, this.amount, this.date);

  factory GiftBalanceMove.fromJson(Map<String, dynamic> j) => GiftBalanceMove(
      (j['label'] ?? '').toString(),
      _d(j['amount']),
      (j['created_at'] ?? '').toString());
}

/// GET /gift-cards — المبالغ بالليرة.
class GiftCardsSummary {
  final double balance;
  final bool onlineEnabled;
  final List<double> presets;
  final double minAmount;
  final double maxAmount;
  final List<GiftCard> cards;
  final List<GiftBalanceMove> moves;

  const GiftCardsSummary({
    required this.balance,
    required this.onlineEnabled,
    this.presets = const [],
    this.minAmount = 0,
    this.maxAmount = 0,
    this.cards = const [],
    this.moves = const [],
  });

  factory GiftCardsSummary.fromJson(Map<String, dynamic> j) {
    List<Map<String, dynamic>> maps(dynamic v) => v is List
        ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : const [];
    return GiftCardsSummary(
      balance: _d(j['balance']),
      onlineEnabled: j['online_enabled'] == true,
      presets: j['presets'] is List
          ? (j['presets'] as List).map(_d).toList()
          : const [],
      minAmount: _d(j['min_amount']),
      maxAmount: _d(j['max_amount']),
      cards: maps(j['cards']).map(GiftCard.fromJson).toList(),
      moves: maps(j['transactions']).map(GiftBalanceMove.fromJson).toList(),
    );
  }
}

class GiftCardService {
  final ApiClient _api = ApiClient();

  Future<GiftCardsSummary> fetch() async {
    final data = await _api.get('/gift-cards');
    return GiftCardsSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  Future<GiftCard> show(int id) async {
    final data = await _api.get('/gift-cards/$id');
    return GiftCard.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// يعيد رقم البطاقة ورابط صفحة البنك (لا تُدخل بيانات البطاقة داخل التطبيق).
  Future<({int id, String url})> purchase(double amount,
      {String? recipientName, String? message}) async {
    final data = await _api.post('/gift-cards/purchase', body: {
      'amount': amount.round(),
      if (recipientName != null && recipientName.trim().isNotEmpty)
        'recipient_name': recipientName.trim(),
      if (message != null && message.trim().isNotEmpty)
        'message': message.trim(),
    });
    final map = Map<String, dynamic>.from(data as Map);
    return (
      id: int.tryParse('${map['id']}') ?? 0,
      url: (map['url'] ?? '').toString()
    );
  }

  /// يعيد رسالة النجاح. الرفض يرمي ApiException برسالته.
  Future<String> redeem(String code) async {
    final data =
        await _api.post('/gift-cards/redeem', body: {'code': code.trim()});
    return (data is Map ? data['message'] : null)?.toString() ?? '';
  }

  Future<bool> openBankPage(String url) =>
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

  /// ينتظر نتيجة البنك (كل 3 ثوانٍ حتى دقيقة). السيرفر هو المرجع.
  Future<GiftCard?> waitForPayment(int id, {int attempts = 20}) async {
    GiftCard? last;
    for (var i = 0; i < attempts; i++) {
      last = await show(id);
      if (last.isFinal) return last;
      await Future.delayed(const Duration(seconds: 3));
    }
    return last;
  }
}
