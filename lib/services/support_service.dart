import 'api_client.dart';

/// سطر مما فعله فريق الدعم في المتجر (بلا أسماء الموظفين).
class SupportAccessAction {
  const SupportAccessAction({required this.description, this.at});

  final String description;
  final DateTime? at;
}

/// إذن البائع لفريق الدعم بفتح لوحة متجره: يبقى حتى يُنهيه البائع.
class SupportAccessState {
  const SupportAccessState({
    required this.active,
    this.grantedAt,
    this.actions = const [],
  });

  final bool active;
  final DateTime? grantedAt;
  final List<SupportAccessAction> actions;

  factory SupportAccessState.fromJson(Map<String, dynamic> json) {
    final actions = json['actions'] is List ? json['actions'] as List : [];
    return SupportAccessState(
      active: json['active'] == true,
      grantedAt: DateTime.tryParse(json['granted_at']?.toString() ?? ''),
      actions: actions
          .whereType<Map>()
          .map((a) => SupportAccessAction(
                description: a['description']?.toString() ?? '',
                at: DateTime.tryParse(a['at']?.toString() ?? ''),
              ))
          .where((a) => a.description.isNotEmpty)
          .toList(),
    );
  }
}

class SupportService {
  final ApiClient _api = ApiClient();

  /// حالة إذن فريق الدعم بفتح لوحة المتجر، وما فعله فيها.
  Future<SupportAccessState> getAccess() async {
    final data = await _api.get('/seller/support-access');
    return _accessFrom(data);
  }

  /// يسمح لفريق الدعم بفتح لوحة المتجر حتى يُنهي البائع الإذن.
  Future<SupportAccessState> grantAccess() async {
    final data = await _api.post('/seller/support-access');
    return _accessFrom(data);
  }

  /// يُنهي الإذن: يُغلق عند الموظف فوراً.
  Future<SupportAccessState> revokeAccess() async {
    final data = await _api.delete('/seller/support-access');
    return _accessFrom(data);
  }

  SupportAccessState _accessFrom(dynamic data) {
    final body = data is Map && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};
    return SupportAccessState.fromJson(body);
  }

  /// جلب محادثات الدعم للبائع
  Future<List<Map<String, dynamic>>> getConversations() async {
    final data = await _api.get('/seller/support');
    final list = data['conversations'] as List?;
    return (list ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  /// إنشاء محادثة دعم جديدة: تصل لكل فريق الدعم (لا يُختار موظف بالاسم)
  Future<Map<String, dynamic>> createConversation({
    required String subject,
    required String body,
  }) async {
    final data = await _api.post('/seller/support', body: {
      'subject': subject,
      'body': body,
    });
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// جلب تفاصيل محادثة مع رسائلها
  Future<Map<String, dynamic>> getConversation(int conversationId) async {
    final data = await _api.get('/seller/support/$conversationId');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  /// إرسال رد على محادثة
  Future<Map<String, dynamic>> sendMessage({
    required int conversationId,
    required String body,
  }) async {
    final data = await _api.post(
      '/seller/support/$conversationId/message',
      body: {'body': body},
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}
