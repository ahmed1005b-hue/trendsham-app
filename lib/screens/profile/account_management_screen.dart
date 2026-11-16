import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../services/account_service.dart';
import '../../services/api_exception.dart';
import '../../l10n/app_localizations.dart';

/// إدارة الحساب: إيقاف مؤقت، أو حذف نهائي بعد مهلة (والبائع يرسل طلباً للإدارة).
class AccountManagementScreen extends StatefulWidget {
  const AccountManagementScreen({super.key, this.service});

  /// قابل للاستبدال في الاختبارات.
  final AccountService? service;

  @override
  State<AccountManagementScreen> createState() => _AccountManagementScreenState();
}

class _AccountManagementScreenState extends State<AccountManagementScreen> {
  late final AccountService _service = widget.service ?? AccountService();
  AccountClosureStatus? _status;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final s = await _service.status();
      if (mounted) setState(() => _status = s);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل بيانات الحساب.');
    }
  }

  /// بعد إغلاق الحساب: مسح الجلسة محلياً والعودة للبداية مع رسالة.
  Future<void> _closeSession(String message) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await context.read<AuthProvider>().closeLocalSession();
    navigator.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: AppText(message), duration: const Duration(seconds: 6)));
  }

  Future<void> _deactivate() async {
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: 'إيقاف الحساب مؤقتاً',
        body: 'ستخرج من كل الأجهزة ولن تصلك إشعارات. يعود حسابك بمجرد تسجيل الدخول مجدداً.',
        action: 'إيقاف الحساب',
        needsPassword: _status!.hasPassword,
      ),
    );
    if (password == null || !mounted) return;
    await _run(() async {
      final message = await _service.deactivate(password: _status!.hasPassword ? password : null);
      if (mounted) await _closeSession(message);
    });
  }

  Future<void> _delete() async {
    final s = _status!;
    final password = await showDialog<String>(
      context: context,
      builder: (_) => _ConfirmDialog(
        title: s.canSelfDelete ? 'حذف الحساب نهائياً' : 'طلب حذف الحساب',
        body: s.canSelfDelete
            ? 'سيُغلق حسابك الآن وتُحذف بياناتك الشخصية بعد ${s.graceDays} يوماً. يمكنك التراجع بتسجيل الدخول خلال هذه المهلة.'
            : 'سيصل طلبك إلى الإدارة لتسوية رصيد المتجر وطلباته قبل إتمام الحذف.',
        action: s.canSelfDelete ? 'حذف حسابي' : 'إرسال الطلب',
        needsPassword: s.hasPassword,
        typeToConfirm: s.canSelfDelete ? 'حذف' : null,
        destructive: true,
      ),
    );
    if (password == null || !mounted) return;
    await _run(() async {
      final r = await _service.delete(password: s.hasPassword ? password : null);
      if (!mounted) return;
      if (r.result == 'scheduled') {
        await _closeSession(r.message);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(r.message)));
        await _load();
      }
    });
  }

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر إتمام العملية. تحقق من الاتصال وحاول مجدداً.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('إدارة الحساب')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AppText(_error!, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                setState(() => _error = null);
                _load();
              },
              child: const AppText('إعادة المحاولة'),
            ),
          ]),
        ),
      );
    }
    final s = _status;
    if (s == null) return const Center(child: CircularProgressIndicator());

    if (s.role == 'admin') {
      return const Center(child: AppText('حسابات المديرين لا تُدار من هنا.'));
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Section(
          icon: Icons.pause_circle_outline,
          color: context.goldText,
          title: 'إيقاف الحساب مؤقتاً',
          lines: const [
            'تخرج من كل الأجهزة ولن تصلك إشعارات.',
            'بياناتك وطلباتك ونقاطك تبقى كما هي.',
            'يعود حسابك بمجرد تسجيل الدخول مجدداً.',
          ],
          button: OutlinedButton(
            onPressed: _busy ? null : _deactivate,
            child: const AppText('إيقاف الحساب'),
          ),
        ),
        const SizedBox(height: 14),
        _Section(
          icon: Icons.delete_forever_outlined,
          color: AppColors.danger,
          title: 'حذف الحساب نهائياً',
          lines: s.canSelfDelete
              ? [
                  'يُغلق حسابك فوراً وتخرج من كل الأجهزة.',
                  'بعد ${s.graceDays} يوماً تُحذف بياناتك الشخصية: الاسم والهاتف والبريد والصورة والعناوين والبطاقات والمفضلة والسلة.',
                  'غيّرت رأيك؟ سجّل الدخول خلال المهلة فيُلغى الطلب.',
                  'تبقى سجلات الطلبات السابقة لدى البائعين باسم «مستخدم محذوف»، ونقاط الولاء تُفقد.',
                ]
              : [
                  'حساب المتجر مرتبط برصيد وطلبات وسجلات مالية.',
                  'لذلك تراجع الإدارة طلب الحذف وتتواصل معك لتسوية الرصيد قبل إتمامه.',
                ],
          warning: s.blockers.isNotEmpty
              ? s.blockers.first
              : (!s.canSelfDelete && s.deletionRequestedAt != null
                  ? 'أرسلت طلب الحذف، والإدارة ستتواصل معك لإتمامه.'
                  : null),
          button: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _busy ||
                    s.blockers.isNotEmpty ||
                    (!s.canSelfDelete && s.deletionRequestedAt != null)
                ? null
                : _delete,
            child: AppText(s.canSelfDelete ? 'حذف حسابي' : 'إرسال طلب الحذف'),
          ),
        ),
      ],
    );
  }
}

class _Section extends StatelessWidget {
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.lines,
    required this.button,
    this.warning,
  });

  final IconData icon;
  final Color color;
  final String title;
  final List<String> lines;
  final Widget button;
  final String? warning;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(icon, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ]),
          const SizedBox(height: 10),
          for (final l in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Padding(
                  padding: const EdgeInsets.only(top: 7),
                  child: Icon(Icons.circle, size: 5, color: context.mutedText),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(l, style: TextStyle(fontSize: 13, height: 1.5, color: context.mutedText)),
                ),
              ]),
            ),
          if (warning != null) ...[
            const SizedBox(height: 4),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.softTint(AppColors.gold),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppText(warning!, style: const TextStyle(fontSize: 13)),
            ),
          ],
          const SizedBox(height: 12),
          Align(alignment: AlignmentDirectional.centerStart, child: button),
        ],
      ),
    );
  }
}

/// تأكيد: كلمة السر (إن وُجدت) وكتابة كلمة محددة للحذف. يعيد كلمة السر ('' بلا كلمة سر) أو null عند الإلغاء.
class _ConfirmDialog extends StatefulWidget {
  const _ConfirmDialog({
    required this.title,
    required this.body,
    required this.action,
    required this.needsPassword,
    this.typeToConfirm,
    this.destructive = false,
  });

  final String title;
  final String body;
  final String action;
  final bool needsPassword;
  final String? typeToConfirm;
  final bool destructive;

  @override
  State<_ConfirmDialog> createState() => _ConfirmDialogState();
}

class _ConfirmDialogState extends State<_ConfirmDialog> {
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  bool get _ready =>
      (!widget.needsPassword || _password.text.isNotEmpty) &&
      (widget.typeToConfirm == null || _typedConfirmWord(_confirm.text));

  /// الكلمة بالعربية أو كما تظهر بلغة الواجهة («Delete» / «Sil»)؛ السيرفر يقبل الثلاث.
  bool _typedConfirmWord(String typed) {
    final want = widget.typeToConfirm!;
    final t = typed.trim().toLowerCase();
    return t == want || t == context.tr(want).toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: AppText(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(widget.body),
            if (widget.needsPassword) ...[
              const SizedBox(height: 14),
              TextField(
                key: const Key('closure-password'),
                controller: _password,
                obscureText: _obscure,
                autofillHints: const [AutofillHints.password],
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: context.tr('كلمة السر'),
                  suffixIcon: IconButton(
                    tooltip: _obscure ? 'إظهار كلمة السر' : 'إخفاء كلمة السر',
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                ),
              ),
            ],
            if (widget.typeToConfirm != null) ...[
              const SizedBox(height: 12),
              TextField(
                key: const Key('closure-confirm'),
                controller: _confirm,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: context.tr('اكتب «${widget.typeToConfirm}» للتأكيد')),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const AppText('تراجع')),
        TextButton(
          onPressed: _ready ? () => Navigator.pop(context, _password.text) : null,
          style: widget.destructive ? TextButton.styleFrom(foregroundColor: AppColors.danger) : null,
          child: AppText(widget.action),
        ),
      ],
    );
  }
}
