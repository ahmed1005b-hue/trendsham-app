import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/notification.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/api_exception.dart';
import '../../services/push_service.dart';
import '../../utils/notification_router.dart';
import 'notification_settings_screen.dart';
import '../../widgets/app_state_message.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<AppNotification>? _notifications;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
    PushService.instance.incoming.addListener(_load);
  }

  @override
  void dispose() {
    PushService.instance.incoming.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final notifications = await _notificationService.list();
      if (mounted) setState(() => _notifications = notifications);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الإشعارات.');
    }
  }

  /// يعلّمه مقروءاً ثم يفتح الشاشة المرتبطة به (طلب، محادثة، منتج…) إن وُجدت.
  Future<void> _open(AppNotification n) async {
    if (!n.read) {
      try {
        await _notificationService.markRead(n.id);
      } catch (_) {}
    }
    final screen = n.targetScreen;
    if (screen != null && screen != 'notifications' && mounted) {
      await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => NotificationRouter.widgetFor(screen, n.targetId),
      ));
    }
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('الإشعارات'),
        actions: [
          IconButton(
            tooltip: context.tr('إعدادات الإشعارات'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => const NotificationSettingsScreen(),
            )),
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_notifications == null) {
      return const LoadingIndicator();
    }
    if (_notifications!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد إشعارات.', icon: Icons.notifications_none);
    }

    return ListView.separated(
      itemCount: _notifications!.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final n = _notifications![index];
        return ListTile(
          tileColor: n.read
              ? null
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          leading: Icon(
            n.read ? Icons.notifications_none : Icons.notifications_active,
            color: n.read ? AppColors.muted : AppColors.emerald,
          ),
          title: AppText(n.title,
              style: TextStyle(
                  fontWeight: n.read ? FontWeight.normal : FontWeight.bold)),
          subtitle: n.body != null ? AppText(n.body!) : null,
          trailing: n.targetScreen != null && n.targetScreen != 'notifications'
              ? const Icon(Icons.chevron_left, color: AppColors.muted)
              : null,
          onTap: () => _open(n),
        );
      },
    );
  }
}
