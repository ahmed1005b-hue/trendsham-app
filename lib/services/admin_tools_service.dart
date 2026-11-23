import 'api_client.dart';

/// نوع في المحذوفات: (المفتاح، الاسم، العدد)
typedef TrashType = (String, String, int);

class TrashItem {
  const TrashItem(
      {required this.id, required this.title, this.detail, this.deletedAt});

  final int id;
  final String title;
  final String? detail;
  final DateTime? deletedAt;

  factory TrashItem.fromJson(Map<String, dynamic> j) => TrashItem(
        id: (j['id'] as num).toInt(),
        title: '${j['title'] ?? ''}',
        detail: j['detail']?.toString(),
        deletedAt: DateTime.tryParse('${j['deleted_at'] ?? ''}'),
      );
}

class TrashPage {
  const TrashPage(this.current, this.types, this.items);

  final String current;
  final List<TrashType> types;
  final List<TrashItem> items;
}

class ChatSummary {
  const ChatSummary(
      {required this.id,
      required this.customer,
      this.lastMessage,
      this.escalatedAt});

  final int id;
  final String customer;
  final String? lastMessage;
  final DateTime? escalatedAt;

  factory ChatSummary.fromJson(Map<String, dynamic> j) => ChatSummary(
        id: (j['id'] as num).toInt(),
        customer: '${j['customer'] ?? ''}',
        lastMessage: j['last_message']?.toString(),
        escalatedAt: DateTime.tryParse('${j['escalated_at'] ?? ''}'),
      );
}

class ChatLine {
  const ChatLine(
      {required this.role,
      required this.content,
      this.agent = false,
      this.agentName,
      this.at});

  /// user = العميل، assistant = المساعد أو الموظف
  final String role;
  final String content;
  final bool agent;
  final String? agentName;
  final DateTime? at;

  bool get fromCustomer => role == 'user';

  factory ChatLine.fromJson(Map<String, dynamic> j) => ChatLine(
        role: '${j['role'] ?? ''}',
        content: '${j['content'] ?? ''}',
        agent: j['agent'] == true,
        agentName: j['agent_name']?.toString(),
        at: DateTime.tryParse('${j['created_at'] ?? ''}'),
      );
}

class ChatThread {
  const ChatThread(
      {required this.id,
      required this.status,
      required this.customer,
      required this.messages});

  final int id;
  final String status;
  final String customer;
  final List<ChatLine> messages;

  bool get isOpen => status == 'escalated';

  factory ChatThread.fromJson(Map<String, dynamic> j) => ChatThread(
        id: (j['id'] as num).toInt(),
        status: '${j['status'] ?? ''}',
        customer: '${j['customer'] ?? ''}',
        messages: (j['messages'] as List? ?? const [])
            .whereType<Map>()
            .map((m) => ChatLine.fromJson(Map<String, dynamic>.from(m)))
            .toList(),
      );
}

class AssistantFaq {
  const AssistantFaq({
    this.id,
    required this.question,
    required this.keywords,
    required this.answer,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final int? id;
  final String question;
  final String keywords;
  final String answer;
  final bool isActive;
  final int sortOrder;

  factory AssistantFaq.fromJson(Map<String, dynamic> j) => AssistantFaq(
        id: (j['id'] as num?)?.toInt(),
        question: '${j['question'] ?? ''}',
        keywords: '${j['keywords'] ?? ''}',
        answer: '${j['answer'] ?? ''}',
        isActive: j['is_active'] == true,
        sortOrder: (j['sort_order'] as num?)?.toInt() ?? 0,
      );

  Map<String, dynamic> toJson() => {
        'question': question,
        'keywords': keywords,
        'answer': answer,
        'is_active': isActive,
        'sort_order': sortOrder,
      };
}

/// حالة التحقق بخطوتين لحساب المدير، ومعلومات الإعداد قبل التفعيل.
class TwoFactorStatus {
  const TwoFactorStatus({
    required this.required,
    required this.enabled,
    this.recoveryRemaining = 0,
    this.secret,
    this.otpauthUrl,
    this.qrSvg,
  });

  final bool required;
  final bool enabled;
  final int recoveryRemaining;
  final String? secret;
  final String? otpauthUrl;
  final String? qrSvg;

  /// المدير لا يدخل لوحته قبل إعداد التحقق (مثل الموقع)
  bool get needsSetup => required && !enabled;

  factory TwoFactorStatus.fromJson(Map<String, dynamic> j) => TwoFactorStatus(
        required: j['required'] == true,
        enabled: j['enabled'] == true,
        recoveryRemaining: (j['recovery_remaining'] as num?)?.toInt() ?? 0,
        secret: j['secret']?.toString(),
        otpauthUrl: j['otpauth_url']?.toString(),
        qrSvg: j['qr_svg']?.toString(),
      );
}

/// المحذوفات، والمساعد الذكي، وأمان حساب المدير (نفس صفحات الموقع).
class AdminToolsService {
  final ApiClient _api = ApiClient();

  Map<String, dynamic> _map(dynamic d) => Map<String, dynamic>.from(d as Map);

  List<Map<String, dynamic>> _list(dynamic d) => (d as List? ?? const [])
      .whereType<Map>()
      .map((m) => Map<String, dynamic>.from(m))
      .toList();

  // ===== المحذوفات =====
  Future<TrashPage> trash({String? type}) async {
    final d = _map(await _api
        .get('/admin/trash', query: {if (type != null) 'type': type}));
    return TrashPage(
      '${d['current'] ?? ''}',
      _list(d['types'])
          .map((t) => (
                '${t['value']}',
                '${t['label']}',
                (t['count'] as num?)?.toInt() ?? 0,
              ))
          .toList(),
      _list(d['data']).map(TrashItem.fromJson).toList(),
    );
  }

  Future<String> restore(String type, int id) async {
    final d = _map(await _api.post('/admin/trash/$type/$id/restore'));
    return '${d['message'] ?? ''}';
  }

  // ===== المساعد: المحادثات =====
  Future<List<ChatSummary>> chats({bool closed = false}) async {
    final d = _map(await _api.get('/admin/assistant-chats',
        query: {if (closed) 'status': 'closed'}));
    return _list(d['data']).map(ChatSummary.fromJson).toList();
  }

  Future<ChatThread> chat(int id) async =>
      ChatThread.fromJson(_map(await _api.get('/admin/assistant-chats/$id')));

  Future<ChatThread> reply(int id, String message) async => ChatThread.fromJson(
      _map(await _api.post('/admin/assistant-chats/$id/reply',
          body: {'message': message})));

  Future<ChatThread> closeChat(int id) async => ChatThread.fromJson(
      _map(await _api.post('/admin/assistant-chats/$id/close')));

  // ===== المساعد: الأسئلة الشائعة =====
  Future<List<AssistantFaq>> faqs() async {
    final d = _map(await _api.get('/admin/assistant-faqs'));
    return _list(d['data']).map(AssistantFaq.fromJson).toList();
  }

  Future<AssistantFaq> saveFaq(AssistantFaq faq) async {
    final d = faq.id == null
        ? await _api.post('/admin/assistant-faqs', body: faq.toJson())
        : await _api.put('/admin/assistant-faqs/${faq.id}', body: faq.toJson());
    return AssistantFaq.fromJson(_map(_map(d)['data']));
  }

  Future<void> deleteFaq(int id) async {
    await _api.delete('/admin/assistant-faqs/$id');
  }

  // ===== أمان حساب المدير =====
  Future<TwoFactorStatus> twoFactor() async => TwoFactorStatus.fromJson(
      _map(await _api.get('/admin/security/two-factor')));

  /// يفعّل التحقق برمز من تطبيق المصادقة، ويعيد رموز الاسترداد (تظهر مرة واحدة)
  Future<List<String>> confirmTwoFactor(String code) async {
    final d = _map(
        await _api.post('/admin/security/two-factor', body: {'code': code}));
    return (d['recovery_codes'] as List? ?? const []).map((c) => '$c').toList();
  }

  Future<List<String>> renewRecoveryCodes(String code) async {
    final d = _map(await _api.post('/admin/security/two-factor/recovery-codes',
        body: {'code': code}));
    return (d['recovery_codes'] as List? ?? const []).map((c) => '$c').toList();
  }
}
