import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'api_client.dart';

/// بطاقة داخل رد المساعد: منتج، طلب، أو رابط لشاشة داخلية.
class ChatCard {
  final String type;
  final int id;
  final String? slug;
  final String title;
  final String? subtitle;
  final String? oldPrice;
  final String? image;
  final bool inStock;

  /// للبطاقات من نوع link: اسم الشاشة (login | coupons | orders)
  final String? route;

  const ChatCard({
    required this.type,
    required this.id,
    required this.title,
    this.slug,
    this.subtitle,
    this.oldPrice,
    this.image,
    this.inStock = true,
    this.route,
  });

  factory ChatCard.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString() ?? 'link';
    return ChatCard(
      type: type,
      id: (json['id'] as num?)?.toInt() ?? 0,
      slug: json['slug']?.toString(),
      title: (type == 'product'
                  ? json['name']
                  : type == 'order'
                      ? json['order_number']
                      : json['title'])
              ?.toString() ??
          '',
      subtitle: (type == 'product'
              ? json['price_label']
              : type == 'order'
                  ? json['status_label']
                  : null)
          ?.toString(),
      oldPrice: json['old_price_label']?.toString(),
      image: json['image']?.toString(),
      inStock: json['in_stock'] != false,
      route: json['route']?.toString(),
    );
  }
}

class ChatMessage {
  final int id;
  final String role;
  final String content;
  final DateTime? createdAt;
  final List<ChatCard> cards;
  final List<String> chips;
  final bool isAgent;
  final String? agentName;
  final bool awaitingConfirmation;

  const ChatMessage({
    required this.role,
    required this.content,
    this.id = 0,
    this.createdAt,
    this.cards = const [],
    this.chips = const [],
    this.isAgent = false,
    this.agentName,
    this.awaitingConfirmation = false,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    // PHP يرسل الكائن الفارغ أحياناً كقائمة []
    final rawMeta = json['meta'];
    final meta =
        rawMeta is Map ? Map<String, dynamic>.from(rawMeta) : <String, dynamic>{};

    return ChatMessage(
      id: (json['id'] as num?)?.toInt() ?? 0,
      role: json['role']?.toString() ?? 'assistant',
      content: json['content']?.toString() ?? '',
      createdAt: json['created_at'] == null
          ? null
          : DateTime.tryParse(json['created_at'].toString()),
      cards: (meta['cards'] is List ? meta['cards'] as List : const [])
          .whereType<Map>()
          .map((c) => ChatCard.fromJson(Map<String, dynamic>.from(c)))
          .toList(),
      chips: (meta['chips'] is List ? meta['chips'] as List : const [])
          .map((c) => c.toString())
          .toList(),
      isAgent: meta['agent'] == true,
      agentName: meta['agent_name']?.toString(),
      awaitingConfirmation: meta['awaiting_confirmation'] == true,
    );
  }
}

class ChatHistory {
  final String status;
  final List<ChatMessage> messages;

  const ChatHistory({required this.status, required this.messages});

  bool get escalated => status == 'escalated';
}

class ChatSendResult {
  final String status;

  /// null حين تكون المحادثة عند موظف: الرد يصل لاحقاً
  final ChatMessage? reply;

  /// رسالة العميل كما حُفظت (برقمها) — لتستبدل النسخة المحلية
  final ChatMessage? message;

  const ChatSendResult({required this.status, this.reply, this.message});

  bool get escalated => status == 'escalated';

  factory ChatSendResult.fromJson(Map<String, dynamic> json) {
    final reply = json['reply'];
    final message = json['message'];
    return ChatSendResult(
      status: json['status']?.toString() ?? 'open',
      message: message is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(message))
          : null,
      reply: reply is Map
          ? ChatMessage.fromJson(Map<String, dynamic>.from(reply))
          : null,
    );
  }
}

class ChatService {
  static const _guestIdKey = 'trendsham_chat_guest_id';
  final ApiClient _api = ApiClient();

  Future<ChatHistory> conversation() async {
    final guestId = await _guestId();
    final response = await _api.get(
      '/chat',
      query: {'guest_id': guestId},
    );
    final messages = response is Map ? response['messages'] : null;
    if (messages is! List) {
      throw const FormatException('استجابة المحادثة غير صالحة.');
    }

    return ChatHistory(
      status: (response as Map)['status']?.toString() ?? 'open',
      messages: messages
          .whereType<Map>()
          .map((message) =>
              ChatMessage.fromJson(Map<String, dynamic>.from(message)))
          .where((message) => message.content.isNotEmpty)
          .toList(),
    );
  }

  Future<ChatSendResult> send(String message) async {
    final guestId = await _guestId();
    final response = await _api.post(
      '/chat/send',
      body: {
        'message': message,
        'guest_id': guestId,
      },
    );
    if (response is! Map) {
      throw const FormatException('استجابة المساعد غير صالحة.');
    }

    return ChatSendResult.fromJson(Map<String, dynamic>.from(response));
  }

  Future<String> _guestId() async {
    final preferences = await SharedPreferences.getInstance();
    final existingId = preferences.getString(_guestIdKey);
    if (existingId != null && existingId.isNotEmpty) return existingId;

    final random = Random.secure();
    final guestId = List<int>.generate(32, (_) => random.nextInt(16))
        .map((digit) => digit.toRadixString(16))
        .join();
    await preferences.setString(_guestIdKey, guestId);
    return guestId;
  }
}
