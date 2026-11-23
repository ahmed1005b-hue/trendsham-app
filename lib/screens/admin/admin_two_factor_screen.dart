import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_tools_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// «أمان الحساب» للمدير (نفس صفحة الموقع): إعداد التحقق بخطوتين وتجديد رموز الاسترداد.
/// تظهر أيضاً قبل اللوحة كلها عندما لا يكون التحقق معدّاً، فاللوحة مقفلة حتى يُعدّ.
class AdminTwoFactorScreen extends StatefulWidget {
  const AdminTwoFactorScreen({super.key, this.service, this.onEnabled});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminToolsService? service;

  /// يُستدعى بعد التفعيل وحفظ الرموز (لفتح اللوحة)
  final VoidCallback? onEnabled;

  @override
  State<AdminTwoFactorScreen> createState() => _AdminTwoFactorScreenState();
}

class _AdminTwoFactorScreenState extends State<AdminTwoFactorScreen> {
  late final AdminToolsService _service = widget.service ?? AdminToolsService();
  final _code = TextEditingController();
  TwoFactorStatus? _status;
  List<String>? _recoveryCodes;
  String? _error;
  String? _formError;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final s = await _service.twoFactor();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال بالسيرفر.');
    }
  }

  Future<void> _submit() async {
    final code = _code.text.trim();
    if (code.isEmpty) {
      setState(() => _formError = 'اكتب الرمز من تطبيق المصادقة.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final codes = _status!.enabled
          ? await _service.renewRecoveryCodes(code)
          : await _service.confirmTwoFactor(code);
      if (!mounted) return;
      _code.clear();
      setState(() => _recoveryCodes = codes);
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) setState(() => _formError = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openAuthenticator(String url) async {
    final ok =
        await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: AppText(
              'لم نجد تطبيق مصادقة على هاتفك. ثبّت Google Authenticator ثم جرّب مرة أخرى، أو انسخ الرمز السري.')));
    }
  }

  void _copy(String text) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: AppText('تم النسخ')));
  }

  @override
  Widget build(BuildContext context) {
    final s = _status;
    return Scaffold(
      appBar: AppBar(title: const AppText('أمان الحساب')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : s == null
              ? const LoadingIndicator()
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _recoveryCodes != null
                      ? _codesView(_recoveryCodes!, s.enabled)
                      : (s.enabled ? _enabledView(s) : _setupView(s)),
                ),
    );
  }

  /// الرموز تظهر مرة واحدة فقط: يحفظها المدير ثم يكمل.
  List<Widget> _codesView(List<String> codes, bool wasEnabled) => [
        const Icon(Icons.verified_user, size: 56, color: AppColors.emerald),
        const SizedBox(height: 8),
        const AppText('رموز الاسترداد',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const AppText(
            'تظهر مرة واحدة فقط. اكتبها على ورقة أو احفظها في مكان آمن. كل رمز يعمل مرة واحدة إذا فقدت هاتفك.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 12),
        Card(
          key: const ValueKey('two-factor-codes'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 16,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final c in codes)
                  SelectableText(c,
                      style: const TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 16,
                          fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => _copy(codes.join('\n')),
          icon: const Icon(Icons.copy),
          label: const AppText('نسخ الرموز'),
        ),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('two-factor-done'),
          onPressed: () {
            setState(() => _recoveryCodes = null);
            if (!wasEnabled && widget.onEnabled != null) {
              widget.onEnabled!();
            } else {
              _load();
            }
          },
          child: const AppText('حفظتها، تابع'),
        ),
      ];

  List<Widget> _setupView(TwoFactorStatus s) => [
        const Icon(Icons.shield_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 8),
        const AppText('فعّل التحقق بخطوتين',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        const AppText(
            'لحماية لوحة الإدارة: عند الدخول يُطلب رمز من تطبيق المصادقة على هاتفك (مثل Google Authenticator).',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13, color: AppColors.muted)),
        const SizedBox(height: 16),
        const AppText('1. أضف الحساب إلى تطبيق المصادقة',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (s.otpauthUrl != null)
          FilledButton.icon(
            key: const ValueKey('two-factor-open-app'),
            onPressed: () => _openAuthenticator(s.otpauthUrl!),
            icon: const Icon(Icons.open_in_new),
            label: const AppText('افتح تطبيق المصادقة'),
          ),
        if (s.qrSvg != null) ...[
          const SizedBox(height: 8),
          const AppText('أو صوّر هذا الرمز من هاتف آخر:',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          Center(
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(8),
              child: SvgPicture.string(s.qrSvg!, width: 180, height: 180),
            ),
          ),
        ],
        if (s.secret != null)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const AppText('أو اكتب الرمز السري يدوياً:',
                style: TextStyle(fontSize: 12)),
            subtitle: SelectableText(s.secret!,
                style: const TextStyle(
                    fontFamily: 'monospace', fontWeight: FontWeight.bold)),
            trailing: IconButton(
                icon: const Icon(Icons.copy),
                onPressed: () => _copy(s.secret!)),
          ),
        const SizedBox(height: 12),
        const AppText('2. اكتب الرمز الذي يظهر في التطبيق',
            style: TextStyle(fontWeight: FontWeight.bold)),
        ..._codeForm('تفعيل'),
      ];

  List<Widget> _enabledView(TwoFactorStatus s) => [
        const Icon(Icons.verified_user, size: 56, color: AppColors.emerald),
        const SizedBox(height: 8),
        const AppText('التحقق بخطوتين مفعّل',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          const AppText('رموز الاسترداد المتبقية:'),
          Text(' ${s.recoveryRemaining}',
              key: const ValueKey('two-factor-remaining'),
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ]),
        const SizedBox(height: 16),
        const AppText(
            'لإنشاء رموز استرداد جديدة اكتب الرمز من تطبيق المصادقة. الرموز القديمة تتوقف عن العمل.',
            style: TextStyle(fontSize: 13)),
        ..._codeForm('إنشاء رموز جديدة'),
      ];

  List<Widget> _codeForm(String submitLabel) => [
        TextField(
          key: const ValueKey('two-factor-code'),
          controller: _code,
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          maxLength: 10,
          style: const TextStyle(fontSize: 22, letterSpacing: 6),
          decoration: const InputDecoration(hintText: '123456'),
        ),
        if (_formError != null)
          AppText(_formError!, style: const TextStyle(color: AppColors.danger)),
        const SizedBox(height: 8),
        FilledButton(
          key: const ValueKey('two-factor-submit'),
          onPressed: _busy ? null : _submit,
          child: AppText(submitLabel),
        ),
      ];
}
