import 'package:app_settings/app_settings.dart';
import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/notification_settings_service.dart';
import '../../services/push_service.dart';
import '../../widgets/app_state_message.dart';

/// يختار المستخدم أنواع الإشعارات التي تصله على الهاتف. الإعداد محفوظ في الحساب
/// (نفسه على كل أجهزته)، والإشعارات تبقى في صفحة الإشعارات مهما كان الاختيار.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends State<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  final NotificationSettingsService _service = NotificationSettingsService();
  NotificationSettings? _settings;
  String? _error;
  bool? _permission;
  final Set<String> _saving = {};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// عند الرجوع من إعدادات الهاتف نعيد فحص الإذن.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkPermission();
  }

  Future<void> _checkPermission() async {
    final granted = await PushService.instance.permissionGranted();
    if (mounted) setState(() => _permission = granted);
  }

  Future<void> _load() async {
    setState(() => _error = null);
    _checkPermission();
    try {
      final s = await _service.get();
      if (mounted) setState(() => _settings = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل إعدادات الإشعارات.');
    }
  }

  Future<void> _toggle(NotificationGroupSetting group, bool value) async {
    final before = _settings!;
    setState(() {
      _settings = before.withGroup(group.key, value);
      _saving.add(group.key);
    });
    try {
      final saved = await _service.update({group.key: value});
      if (mounted) setState(() => _settings = saved);
    } catch (e) {
      if (!mounted) return;
      setState(() => _settings = before);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(e is ApiException ? e.message : 'تعذّر حفظ الإعداد، حاول مجدداً.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving.remove(group.key));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('إعدادات الإشعارات')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.emerald,
        child: _buildBody(context),
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final s = _settings;
    if (s == null) return const LoadingIndicator();

    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        if (_permission == false) _PermissionBanner(onOpen: _openPhoneSettings),
        if (s.groups.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: AppText('لا توجد إعدادات إشعارات لهذا الحساب.'),
          ),
        for (final g in s.groups)
          SwitchListTile(
            value: g.enabled,
            onChanged: g.locked || _saving.contains(g.key)
                ? null
                : (v) => _toggle(g, v),
            activeThumbColor: AppColors.emerald,
            title: AppText(g.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: AppText(
              g.undecided ? '${g.description}\nمتوقفة حتى تفعّلها.' : g.description,
            ),
            isThreeLine: g.undecided,
          ),
        if (s.alwaysOnNote.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.shield_outlined,
                    size: 18, color: theme.colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(
                    s.alwaysOnNote,
                    style: TextStyle(color: theme.colorScheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _openPhoneSettings() async {
    await AppSettings.openAppSettings(type: AppSettingsType.notification);
  }
}

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onOpen;
  const _PermissionBanner({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined, color: scheme.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: AppText(
              'الإشعارات مغلقة من إعدادات هاتفك، فلن يصلك شيء حتى تفتحها.',
              style: TextStyle(color: scheme.onErrorContainer),
            ),
          ),
          TextButton(
            onPressed: onOpen,
            child: AppText('فتح الإعدادات',
                style: TextStyle(color: scheme.onErrorContainer)),
          ),
        ],
      ),
    );
  }
}
