import 'api_client.dart';

/// حالة الحساب لصفحة "إدارة الحساب".
class AccountClosureStatus {
  final String role;
  final bool canSelfDelete;
  final List<String> blockers;
  final bool hasPassword;
  final int graceDays;
  final DateTime? deletionRequestedAt;

  const AccountClosureStatus({
    required this.role,
    required this.canSelfDelete,
    this.blockers = const [],
    this.hasPassword = true,
    this.graceDays = 30,
    this.deletionRequestedAt,
  });

  factory AccountClosureStatus.fromJson(Map<String, dynamic> j) => AccountClosureStatus(
        role: (j['role'] ?? 'customer').toString(),
        canSelfDelete: j['can_self_delete'] == true,
        blockers: ((j['blockers'] as List?) ?? const []).map((e) => e.toString()).toList(),
        hasPassword: j['has_password'] != false,
        graceDays: (j['grace_days'] as num?)?.toInt() ?? 30,
        deletionRequestedAt: DateTime.tryParse((j['deletion_requested_at'] ?? '').toString()),
      );
}

/// إيقاف الحساب وحذفه: /api/v1/profile/account
class AccountService {
  final ApiClient _api;
  AccountService({ApiClient? api}) : _api = api ?? ApiClient();

  Future<AccountClosureStatus> status() async {
    final data = await _api.get('/profile/account');
    return AccountClosureStatus.fromJson(Map<String, dynamic>.from(data['data'] as Map));
  }

  /// يعيد رسالة السيرفر.
  Future<String> deactivate({String? password}) async {
    final data = await _api.post('/profile/account/deactivate',
        body: {if (password != null) 'password': password});
    return (data['message'] ?? 'تم إيقاف حسابك.').toString();
  }

  /// result: scheduled (عميل: يُحذف بعد المهلة) أو requested (بائع: طلب للإدارة).
  Future<({String result, String message})> delete({String? password}) async {
    final data = await _api.post('/profile/account/delete',
        body: {if (password != null) 'password': password, 'confirm': 'حذف'});
    return (
      result: (data['result'] ?? 'scheduled').toString(),
      message: (data['message'] ?? '').toString(),
    );
  }
}
