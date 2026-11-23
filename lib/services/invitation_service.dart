import '../models/user.dart';
import 'api_client.dart';

/// يستخرج رمز الدعوة من الرابط كاملاً (…/join/رمز) أو يعيد الرمز كما هو.
String invitationTokenFrom(String input) {
  final text = input.trim();
  final i = text.indexOf('/join/');
  if (i < 0) return text;
  final rest = text.substring(i + '/join/'.length);
  return rest.split(RegExp(r'[/?#]')).first.trim();
}

/// معاينة دعوة بائع أو موظف قبل إنشاء الحساب.
class InvitationPreview {
  final String role;
  final String roleLabel;
  final String? storeName;
  final String? phone;
  final String? email;
  final bool usable;
  final String? problem;

  const InvitationPreview({
    required this.role,
    required this.roleLabel,
    this.storeName,
    this.phone,
    this.email,
    this.usable = false,
    this.problem,
  });

  bool get isSeller => role == 'seller';

  factory InvitationPreview.fromJson(Map<String, dynamic> json) =>
      InvitationPreview(
        role: json['role']?.toString() ?? '',
        roleLabel: json['role_label']?.toString() ?? '',
        storeName: json['store_name']?.toString(),
        phone: json['phone']?.toString(),
        email: json['email']?.toString(),
        usable: json['usable'] == true,
        problem: json['problem']?.toString(),
      );
}

/// دعوة في قائمة المدير.
class AdminInvitation {
  final int id;
  final String role;
  final String roleLabel;
  final String? name;
  final String? storeName;
  final String? phone;
  final String? email;
  final String statusLabel;
  final bool usable;
  final String? url;
  final DateTime? expiresAt;

  const AdminInvitation({
    required this.id,
    required this.role,
    required this.roleLabel,
    this.name,
    this.storeName,
    this.phone,
    this.email,
    required this.statusLabel,
    required this.usable,
    this.url,
    this.expiresAt,
  });

  factory AdminInvitation.fromJson(Map<String, dynamic> json) =>
      AdminInvitation(
        id: int.tryParse('${json['id'] ?? 0}') ?? 0,
        role: json['role']?.toString() ?? '',
        roleLabel: json['role_label']?.toString() ?? '',
        name: json['name']?.toString(),
        storeName: json['store_name']?.toString(),
        phone: json['phone']?.toString(),
        email: json['email']?.toString(),
        statusLabel: json['status_label']?.toString() ?? '',
        usable: json['usable'] == true,
        url: json['url']?.toString(),
        expiresAt: DateTime.tryParse(json['expires_at']?.toString() ?? ''),
      );
}

class InvitationService {
  final ApiClient _api = ApiClient();

  Future<InvitationPreview> check(String code) async {
    final token = Uri.encodeComponent(invitationTokenFrom(code));
    final data = await _api.get('/invitations/$token', withAuth: false);
    return InvitationPreview.fromJson(
        Map<String, dynamic>.from((data as Map)['data'] as Map));
  }

  /// قبول الدعوة بحساب العميل الحالي؛ يعيد الحساب بدوره الجديد (بائع/موظف).
  Future<AppUser> accept(String code, {String? storeName}) async {
    final token = Uri.encodeComponent(invitationTokenFrom(code));
    final data = await _api.post('/invitations/$token/accept', body: {
      if (storeName != null && storeName.trim().isNotEmpty)
        'store_name': storeName.trim(),
    });
    return AppUser.fromJson(
        Map<String, dynamic>.from((data as Map)['data'] as Map));
  }

  Future<List<AdminInvitation>> adminList() async {
    final data = await _api.get('/admin/invitations');
    final list =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    return list
        .whereType<Map>()
        .map((m) => AdminInvitation.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  Future<AdminInvitation> adminCreate({
    required String role,
    String? name,
    String? storeName,
    String? phone,
    String? email,
    int days = 7,
  }) async {
    String? clean(String? v) => v == null || v.trim().isEmpty ? null : v.trim();
    final data = await _api.post('/admin/invitations', body: {
      'role': role,
      'days': days,
      if (clean(name) != null) 'name': clean(name),
      if (clean(storeName) != null) 'store_name': clean(storeName),
      if (clean(phone) != null) 'phone': clean(phone),
      if (clean(email) != null) 'email': clean(email),
    });
    return AdminInvitation.fromJson(
        Map<String, dynamic>.from((data as Map)['data'] as Map));
  }

  Future<void> adminRevoke(int id) =>
      _api.post('/admin/invitations/$id/revoke');
}
