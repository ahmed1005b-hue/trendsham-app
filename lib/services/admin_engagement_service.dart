import 'api_client.dart';

/// إشعار جماعي سابق.
class BroadcastItem {
  const BroadcastItem({
    required this.id,
    required this.title,
    required this.body,
    this.link,
    this.creator,
    this.scheduledFor,
    this.sentAt,
    this.recipients = 0,
    this.pushed = 0,
  });

  final int id;
  final String title;
  final String body;
  final String? link;
  final String? creator;
  final DateTime? scheduledFor;
  final DateTime? sentAt;
  final int recipients;
  final int pushed;

  factory BroadcastItem.fromJson(Map<String, dynamic> j) => BroadcastItem(
        id: (j['id'] as num).toInt(),
        title: '${j['title'] ?? ''}',
        body: '${j['body'] ?? ''}',
        link: j['link']?.toString(),
        creator: j['creator']?.toString(),
        scheduledFor: DateTime.tryParse('${j['scheduled_for'] ?? ''}'),
        sentAt: DateTime.tryParse('${j['sent_at'] ?? ''}'),
        recipients: (j['recipients_count'] as num?)?.toInt() ?? 0,
        pushed: (j['pushed_count'] as num?)?.toInt() ?? 0,
      );
}

class BroadcastsPage {
  const BroadcastsPage(
      {required this.total,
      required this.reachable,
      required this.items,
      this.nextAllowedAt});

  final int total;
  final int reachable;
  final DateTime? nextAllowedAt;
  final List<BroadcastItem> items;
}

class GiftCardRow {
  const GiftCardRow({
    required this.id,
    required this.amount,
    required this.status,
    this.statusLabel,
    this.purchaser,
    this.purchaserEmail,
    this.redeemer,
    this.date,
  });

  final int id;
  final double amount;
  final String status;
  final String? statusLabel;
  final String? purchaser;
  final String? purchaserEmail;
  final String? redeemer;
  final DateTime? date;

  factory GiftCardRow.fromJson(Map<String, dynamic> j) => GiftCardRow(
        id: (j['id'] as num).toInt(),
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        status: '${j['status'] ?? ''}',
        statusLabel: j['status_label']?.toString(),
        purchaser: j['purchaser']?.toString(),
        purchaserEmail: j['purchaser_email']?.toString(),
        redeemer: j['redeemer']?.toString(),
        date: DateTime.tryParse('${j['date'] ?? ''}'),
      );
}

class GiftCardsPage {
  const GiftCardsPage(this.totals, this.statuses, this.items);

  /// sold_count, sold_amount, spent, unredeemed, expired_unused, balances, owed
  final Map<String, num> totals;
  final List<(String, String)> statuses;
  final List<GiftCardRow> items;
}

class LoyaltyCustomer {
  const LoyaltyCustomer(
      {required this.userId,
      required this.name,
      this.email,
      this.phone,
      this.balance = 0,
      this.debt = 0,
      this.lifetimeEarned = 0});

  final int userId;
  final String name;
  final String? email;
  final String? phone;
  final int balance;
  final int debt;
  final int lifetimeEarned;

  factory LoyaltyCustomer.fromJson(Map<String, dynamic> j) => LoyaltyCustomer(
        userId: (j['user_id'] as num).toInt(),
        name: '${j['name'] ?? ''}',
        email: j['email']?.toString(),
        phone: j['phone']?.toString(),
        balance: (j['balance'] as num?)?.toInt() ?? 0,
        debt: (j['debt'] as num?)?.toInt() ?? 0,
        lifetimeEarned: (j['lifetime_earned'] as num?)?.toInt() ?? 0,
      );
}

class LoyaltyPage {
  const LoyaltyPage(this.summary, this.settings, this.customers);

  /// outstanding, outstanding_value, earned_this_month, redeemed_this_month, expired_this_month
  final Map<String, num> summary;

  /// loyalty_enabled + الأرقام (المبالغ بالليرة)
  final Map<String, dynamic> settings;
  final List<LoyaltyCustomer> customers;
}

class LoyaltyHistory {
  const LoyaltyHistory(
      {required this.name,
      required this.balance,
      required this.pending,
      required this.debt,
      required this.transactions});

  final String name;
  final int balance;
  final int pending;
  final int debt;

  /// (الوصف، النقاط، التاريخ)
  final List<(String, int, DateTime?)> transactions;
}

/// الإشعار الجماعي، وبطاقات الهدايا، ونقاط الولاء للمدير (نفس صفحات الموقع).
class AdminEngagementService {
  final ApiClient _api = ApiClient();

  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);

  List<Map<String, dynamic>> _list(dynamic d) => (d as List? ?? const [])
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();

  Map<String, num> _nums(dynamic d) => {
        for (final e in _map(d ?? {}).entries)
          if (e.value is num) e.key: e.value as num,
      };

  // ===== الإشعار الجماعي =====
  Future<BroadcastsPage> broadcasts() async {
    final d = _map(await _api.get('/admin/push-broadcasts'));
    final audience = _map(d['audience'] ?? {});
    return BroadcastsPage(
      total: (audience['total'] as num?)?.toInt() ?? 0,
      reachable: (audience['reachable'] as num?)?.toInt() ?? 0,
      nextAllowedAt: DateTime.tryParse('${d['next_allowed_at'] ?? ''}'),
      items: _list(d['data']).map(BroadcastItem.fromJson).toList(),
    );
  }

  Future<String> sendBroadcast(
      {required String title, required String body, String? link}) async {
    final d = _map(await _api.post('/admin/push-broadcasts', body: {
      'title': title,
      'body': body,
      if ((link ?? '').isNotEmpty) 'link': link,
      'confirm': true,
    }));
    return '${d['message'] ?? ''}';
  }

  // ===== بطاقات الهدايا =====
  Future<GiftCardsPage> giftCards({String? status, String? q}) async {
    final d = _map(await _api.get('/admin/gift-cards', query: {
      if (status != null) 'status': status,
      if ((q ?? '').isNotEmpty) 'q': q,
    }));
    return GiftCardsPage(
      _nums(d['totals']),
      _list(d['statuses'])
          .map((m) => ('${m['value']}', '${m['label']}'))
          .toList(),
      _list(d['data']).map(GiftCardRow.fromJson).toList(),
    );
  }

  // ===== نقاط الولاء =====
  Future<LoyaltyPage> loyalty({String? q}) async {
    final d = _map(await _api
        .get('/admin/loyalty', query: {if ((q ?? '').isNotEmpty) 'q': q}));
    return LoyaltyPage(
      _nums(d['summary']),
      _map(d['settings'] ?? {}),
      _list(d['data']).map(LoyaltyCustomer.fromJson).toList(),
    );
  }

  Future<String> saveLoyaltySettings(Map<String, dynamic> settings) async {
    final d = _map(await _api.put('/admin/loyalty/settings', body: settings));
    return '${d['message'] ?? ''}';
  }

  Future<LoyaltyHistory> loyaltyCustomer(int userId) async {
    final d = _map(await _api.get('/admin/loyalty/customers/$userId'));
    return LoyaltyHistory(
      name: '${_map(d['customer'] ?? {})['name'] ?? ''}',
      balance: (d['balance'] as num?)?.toInt() ?? 0,
      pending: (d['pending'] as num?)?.toInt() ?? 0,
      debt: (d['debt'] as num?)?.toInt() ?? 0,
      transactions: _list(d['transactions'])
          .map((t) => (
                '${t['label'] ?? ''}',
                (t['points'] as num?)?.toInt() ?? 0,
                DateTime.tryParse('${t['created_at'] ?? ''}'),
              ))
          .toList(),
    );
  }

  Future<String> adjustPoints(int userId,
      {required bool add, required int points, required String reason}) async {
    final d = _map(await _api.post('/admin/loyalty/customers/$userId/adjust',
        body: {
          'direction': add ? 'add' : 'deduct',
          'points': points,
          'reason': reason
        }));
    return '${d['message'] ?? ''}';
  }
}
