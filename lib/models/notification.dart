class AppNotification {
  final int id;
  final String type;
  final String title;
  final String? body;
  final String? link;
  final bool read;
  final DateTime? createdAt;

  /// المجموعة (orders, messages, offers…) والشاشة التي يفتحها الإشعار.
  final String? group;
  final String? targetScreen;
  final String? targetId;

  AppNotification({
    required this.id,
    required this.type,
    required this.title,
    this.body,
    this.link,
    required this.read,
    this.createdAt,
    this.group,
    this.targetScreen,
    this.targetId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final target = json['target'];
    return AppNotification(
      id: json['id'],
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      body: json['body'],
      link: json['link'],
      read: json['read'] ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'])
          : null,
      group: json['group'],
      targetScreen: target is Map ? target['screen']?.toString() : null,
      targetId: target is Map && target['id'] != null
          ? target['id'].toString()
          : null,
    );
  }
}
