import 'dart:async';
import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../utils/notification_router.dart';
import 'api_client.dart';
import '../l10n/app_localizations.dart';

/// الإشعارات المنبثقة: تهيئة Firebase، طلب الإذن، تسجيل الهاتف في الخادم،
/// وفتح الشاشة عند الضغط على الإشعار. إن لم يكن Firebase متاحاً يعمل التطبيق كالمعتاد بلا إشعارات هاتف.
class PushService {
  PushService._();
  static final PushService instance = PushService._();

  static const _askedKey = 'push_permission_explained';

  final ApiClient _api = ApiClient();
  bool _configured = false;
  bool _initialHandled = false;
  String? _token;

  /// يزيد مع كل إشعار يصل والتطبيق مفتوح (لتحديث الجرس والقوائم).
  final ValueNotifier<int> incoming = ValueNotifier<int>(0);

  bool get isConfigured => _configured;

  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Firebase.initializeApp();
      _configured = true;
    } catch (e) {
      debugPrint('Firebase غير متاح: $e');
      return;
    }

    FirebaseMessaging.onMessage.listen(_onForeground);
    FirebaseMessaging.onMessageOpenedApp.listen(_openFromMessage);
    // ignore: deprecated_member_use
    FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      _token = token;
      unawaited(_postToken(token));
    });
  }

  /// بعد الدخول (أو عند فتح التطبيق والمستخدم مسجّل): شرح ثم إذن، ثم تسجيل الهاتف.
  Future<void> registerDevice() async {
    if (!_configured) return;
    try {
      final context = NotificationRouter.navigatorKey.currentContext;
      if (context != null && context.mounted) {
        await requestPermissionWithExplainer(context);
      }
      // ignore: deprecated_member_use
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      _token = token;
      await _postToken(token);
      await _handleInitialMessage();
    } catch (e) {
      debugPrint('تعذّر تسجيل الجهاز للإشعارات: $e');
    }
  }

  /// قبل تسجيل الخروج: لا تصل إشعارات هذا الحساب لهذا الهاتف بعد الآن.
  Future<void> unregisterDevice() async {
    if (!_configured) return;
    try {
      // ignore: deprecated_member_use
      final token = _token ?? await FirebaseMessaging.instance.getToken();
      if (token == null) return;
      await _api.delete('/push/devices', body: {'token': token});
    } catch (e) {
      debugPrint('تعذّر إلغاء تسجيل الجهاز: $e');
    }
  }

  /// يشرح فائدة الإشعارات مرة واحدة قبل طلب إذن النظام.
  Future<void> requestPermissionWithExplainer(BuildContext context) async {
    final messaging = FirebaseMessaging.instance;
    final current = await messaging.getNotificationSettings();
    if (current.authorizationStatus != AuthorizationStatus.notDetermined) {
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool(_askedKey) ?? false) return;
    await prefs.setBool(_askedKey, true);

    if (!context.mounted) return;
    final accepted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.notifications_active_outlined),
        title: const AppText('فعّل الإشعارات'),
        content: const AppText(
          'نخبرك فوراً عند تأكيد طلبك وشحنه وتسليمه، وعند وصول رسالة جديدة. '
          'يمكنك اختيار ما يصلك من صفحة إعدادات الإشعارات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('ليس الآن'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('تفعيل'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await messaging.requestPermission();
    }
  }

  /// هل أذن المستخدم بالإشعارات من إعدادات الهاتف؟ (null = غير معروف/غير مدعوم)
  Future<bool?> permissionGranted() async {
    if (!_configured) return null;
    final s = await FirebaseMessaging.instance.getNotificationSettings();
    return s.authorizationStatus == AuthorizationStatus.authorized ||
        s.authorizationStatus == AuthorizationStatus.provisional;
  }

  Future<void> _postToken(String token) async {
    await _api.post('/push/devices', body: {
      'token': token,
      'platform': Platform.isIOS ? 'ios' : 'android',
    });
  }

  Future<void> _handleInitialMessage() async {
    if (_initialHandled) return;
    _initialHandled = true;
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _openFromMessage(message);
  }

  void _openFromMessage(RemoteMessage message) {
    NotificationRouter.open(
      message.data['screen']?.toString(),
      message.data['id']?.toString(),
    );
  }

  void _onForeground(RemoteMessage message) {
    incoming.value++;
    final title = message.notification?.title;
    if (title == null) return;
    NotificationRouter.messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: AppText(title),
        duration: const Duration(seconds: 5),
        action: SnackBarAction(
          label: 'عرض',
          onPressed: () => _openFromMessage(message),
        ),
      ),
    );
  }
}
