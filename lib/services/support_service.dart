import 'api_client.dart';

class SupportService {
  final ApiClient _api = ApiClient();

  /// جلب محادثات الدعم للبائع
  Future<List<Map<String, dynamic>>> getConversations() async {
    final data = await _api.get('/seller/support');
    final list = data['conversations'] as List?;
    return (list ?? [])
        .whereType<Map>()
        .map((c) => Map<String, dynamic>.from(c))
        .toList();
  }

  /// إنشاء محادثة دعم جديدة
  Future<Map<String, dynamic>> createConversation({
    required int staffId,
    required String subject,
    required String body,
  }) async {
    final data = await _api.post('/seller/support', body: {
      'staff_id': staffId,
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
