import 'api_client.dart';

int _i(dynamic v) => int.tryParse((v ?? 0).toString()) ?? 0;

/// صديق دعوته (الاسم مختصر من السيرفر).
class InvitedFriend {
  final String name;
  final String status;
  final String statusLabel;
  final String joinedAt;

  const InvitedFriend({
    required this.name,
    required this.status,
    required this.statusLabel,
    required this.joinedAt,
  });

  bool get rewarded => status == 'rewarded';

  factory InvitedFriend.fromJson(Map<String, dynamic> j) => InvitedFriend(
        name: (j['name'] ?? '').toString(),
        status: (j['status'] ?? 'pending').toString(),
        statusLabel: (j['status_label'] ?? '').toString(),
        joinedAt: (j['joined_at'] ?? '').toString(),
      );
}

/// «دعوة صديق» (GET /referrals). المبالغ بالليرة.
class ReferralSummary {
  final String code;
  final String link;
  final String shareText;
  final int rewardPoints;
  final double minOrder;
  final bool canApply;
  final String? referredByName;
  final String? referredByStatusLabel;
  final int joined;
  final int rewarded;
  final int pointsEarned;
  final List<InvitedFriend> invited;

  const ReferralSummary({
    required this.code,
    required this.link,
    required this.shareText,
    required this.rewardPoints,
    required this.minOrder,
    required this.canApply,
    this.referredByName,
    this.referredByStatusLabel,
    this.joined = 0,
    this.rewarded = 0,
    this.pointsEarned = 0,
    this.invited = const [],
  });

  factory ReferralSummary.fromJson(Map<String, dynamic> j) {
    final by = j['referred_by'];
    final stats = j['stats'] is Map ? j['stats'] as Map : const {};
    final invited = j['invited'] is List ? j['invited'] as List : const [];
    return ReferralSummary(
      code: (j['code'] ?? '').toString(),
      link: (j['link'] ?? '').toString(),
      shareText: (j['share_text'] ?? '').toString(),
      rewardPoints: _i(j['reward_points']),
      minOrder: double.tryParse((j['min_order'] ?? 0).toString()) ?? 0,
      canApply: j['can_apply'] == true,
      referredByName: by is Map ? by['name']?.toString() : null,
      referredByStatusLabel: by is Map ? by['status_label']?.toString() : null,
      joined: _i(stats['joined']),
      rewarded: _i(stats['rewarded']),
      pointsEarned: _i(stats['points_earned']),
      invited: invited
          .whereType<Map>()
          .map((e) => InvitedFriend.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
    );
  }
}

class ReferralService {
  final ApiClient _api = ApiClient();

  Future<ReferralSummary> fetchSummary() async {
    final data = await _api.get('/referrals');
    return ReferralSummary.fromJson(Map<String, dynamic>.from(data as Map));
  }

  /// يعيد رسالة النجاح من السيرفر. الرفض يرمي ApiException برسالته.
  Future<String> apply(String code) async {
    final data = await _api.post('/referrals', body: {'code': code.trim()});
    return (data is Map ? data['message'] : null)?.toString() ?? '';
  }
}
