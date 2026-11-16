import 'api_client.dart';

/// مجموعة إشعارات يتحكم بها المستخدم (الطلبات، الرسائل، العروض…).
class NotificationGroupSetting {
  final String key;
  final String label;
  final String description;

  /// null من الخادم = "لم يُحدَّد" (العروض قبل سؤال العميل) ويُعامل كإيقاف.
  final bool? _enabled;
  final bool locked;

  const NotificationGroupSetting({
    required this.key,
    required this.label,
    required this.description,
    required bool? enabled,
    this.locked = false,
  }) : _enabled = enabled;

  bool get enabled => _enabled ?? false;
  bool get undecided => _enabled == null;

  factory NotificationGroupSetting.fromJson(Map<String, dynamic> json) {
    return NotificationGroupSetting(
      key: json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      enabled: json['enabled'] as bool?,
      locked: json['locked'] == true,
    );
  }

  NotificationGroupSetting copyWith({bool? enabled}) => NotificationGroupSetting(
        key: key,
        label: label,
        description: description,
        enabled: enabled ?? _enabled,
        locked: locked,
      );
}

class NotificationSettings {
  final String role;
  final List<NotificationGroupSetting> groups;
  final String alwaysOnNote;
  final bool offersPrompted;

  const NotificationSettings({
    required this.role,
    required this.groups,
    required this.alwaysOnNote,
    required this.offersPrompted,
  });

  factory NotificationSettings.fromJson(Map<String, dynamic> json) {
    return NotificationSettings(
      role: json['role']?.toString() ?? '',
      groups: ((json['groups'] as List?) ?? const [])
          .map((g) => NotificationGroupSetting.fromJson(Map<String, dynamic>.from(g)))
          .toList(),
      alwaysOnNote: json['always_on_note']?.toString() ?? '',
      offersPrompted: json['offers_prompted'] == true,
    );
  }

  NotificationSettings withGroup(String key, bool enabled) => NotificationSettings(
        role: role,
        groups: [
          for (final g in groups) g.key == key ? g.copyWith(enabled: enabled) : g,
        ],
        alwaysOnNote: alwaysOnNote,
        offersPrompted: offersPrompted || key == 'offers',
      );
}

class NotificationSettingsService {
  final ApiClient _api = ApiClient();

  Future<NotificationSettings> get() async {
    final data = await _api.get('/notification-settings');
    return NotificationSettings.fromJson(Map<String, dynamic>.from(data));
  }

  Future<NotificationSettings> update(Map<String, bool> groups) async {
    final data = await _api.put('/notification-settings', body: {'groups': groups});
    return NotificationSettings.fromJson(Map<String, dynamic>.from(data));
  }
}
