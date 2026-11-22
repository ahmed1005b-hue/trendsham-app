import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import 'api_client.dart';

/// أحدث إصدار على المتجر وأقدم إصدار مسموح (من الخادم).
class AppVersionInfo {
  final String latestVersion;
  final String minVersion;
  final String? storeUrl;

  const AppVersionInfo(
      {required this.latestVersion, required this.minVersion, this.storeUrl});

  factory AppVersionInfo.fromJson(Map<String, dynamic> json) => AppVersionInfo(
        latestVersion: json['latest_version']?.toString() ?? '0.0.0',
        minVersion: json['min_version']?.toString() ?? '0.0.0',
        storeUrl: json['store_url']?.toString(),
      );
}

enum UpdateNeed { none, optional, required }

/// يقارن رقمي إصدار مثل 1.2.10 و 1.10.0 (رقماً رقماً، لا كنص). سالب = a أقدم.
int compareVersions(String a, String b) {
  List<int> parts(String v) => v
      .split('+')
      .first
      .split('.')
      .map((p) => int.tryParse(p.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
      .toList();
  final x = parts(a), y = parts(b);
  for (var i = 0; i < 3; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d;
  }
  return 0;
}

UpdateNeed updateNeed(String current, AppVersionInfo info) {
  if (compareVersions(current, info.minVersion) < 0) return UpdateNeed.required;
  if (compareVersions(current, info.latestVersion) < 0) {
    return UpdateNeed.optional;
  }
  return UpdateNeed.none;
}

class AppUpdateService {
  final ApiClient _api = ApiClient();

  Future<AppVersionInfo?> fetch() async {
    final data = await _api.get('/app-version');
    return data is Map
        ? AppVersionInfo.fromJson(Map<String, dynamic>.from(data))
        : null;
  }
}

/// رقم إصدار التطبيق المثبّت (مثل 1.1.0).
Future<String> installedVersion() async =>
    (await PackageInfo.fromPlatform()).version;

/// يفحص عند فتح التطبيق: نسخة أقدم من المسموح ← تحديث إجباري،
/// نسخة أقدم من الأحدث ← «يوجد تحديث جديد» مرة واحدة لكل إصدار.
class AppUpdateGate extends StatefulWidget {
  final Widget child;

  const AppUpdateGate({super.key, required this.child});

  /// مصدر المعلومات؛ الاختبارات تستبدله حتى لا تتصل بالإنترنت.
  @visibleForTesting
  static Future<(String, AppVersionInfo?)> Function() loader = () async {
    final current = await installedVersion();
    return (current, await AppUpdateService().fetch());
  };

  @override
  State<AppUpdateGate> createState() => _AppUpdateGateState();
}

class _AppUpdateGateState extends State<AppUpdateGate> {
  static const _dismissedKey = 'update_dismissed_version';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _check());
  }

  Future<void> _check() async {
    try {
      final (current, info) = await AppUpdateGate.loader();
      if (!mounted || info == null) return;
      final need = updateNeed(current, info);
      if (need == UpdateNeed.none) return;
      final prefs = await SharedPreferences.getInstance();
      if (need == UpdateNeed.optional &&
          prefs.getString(_dismissedKey) == info.latestVersion) {
        return;
      }
      if (!mounted) return;
      final later = await showDialog<bool>(
        context: context,
        barrierDismissible: need == UpdateNeed.optional,
        builder: (_) =>
            _UpdateDialog(info: info, required: need == UpdateNeed.required),
      );
      if (later == true) {
        await prefs.setString(_dismissedKey, info.latestVersion);
      }
    } catch (_) {
      // بدون اتصال: لا شيء، نفحص في المرة القادمة
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _UpdateDialog extends StatelessWidget {
  final AppVersionInfo info;
  final bool required;

  const _UpdateDialog({required this.info, required this.required});

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !required,
      child: AlertDialog(
        icon: const Icon(Icons.system_update_rounded, size: 36),
        title: AppText(required ? 'يجب تحديث التطبيق' : 'يوجد تحديث جديد'),
        content: AppText(required
            ? 'هذه النسخة قديمة ولم تعد تعمل. حدّث التطبيق من المتجر للمتابعة.'
            : 'نسخة جديدة من تريندشام متوفرة، فيها ميزات وتحسينات.'),
        actions: [
          if (!required)
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const AppText('لاحقاً'),
            ),
          if (info.storeUrl != null && info.storeUrl!.startsWith('https://'))
            FilledButton(
              onPressed: () => launchUrl(Uri.parse(info.storeUrl!),
                  mode: LaunchMode.externalApplication),
              child: const AppText('تحديث الآن'),
            ),
        ],
      ),
    );
  }
}

/// «الإصدار 1.1.0» أسفل صفحة الحساب.
class AppVersionLabel extends StatelessWidget {
  const AppVersionLabel({super.key});

  /// الاختبارات تستبدله (لا توجد منصة حقيقية في الاختبار)
  @visibleForTesting
  static Future<String> Function() version = installedVersion;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: version(),
      builder: (context, snapshot) {
        final v = snapshot.data;
        if (v == null) return const SizedBox.shrink();
        return AppText('الإصدار $v',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: Colors.grey));
      },
    );
  }
}
