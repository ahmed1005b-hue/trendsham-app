import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/invitation_service.dart';

/// عميل مسجّل يقبل دعوة بائع أو موظف بحسابه الحالي (مثل زر «قبول الدعوة» في الموقع).
/// بعد القبول يتغيّر دور الحساب فيفتح التطبيق لوحته الجديدة.
Future<void> showAcceptInvitationDialog(BuildContext context) {
  return showDialog<void>(
      context: context, builder: (_) => const _AcceptInvitationDialog());
}

class _AcceptInvitationDialog extends StatefulWidget {
  const _AcceptInvitationDialog();

  @override
  State<_AcceptInvitationDialog> createState() =>
      _AcceptInvitationDialogState();
}

class _AcceptInvitationDialogState extends State<_AcceptInvitationDialog> {
  final _service = InvitationService();
  final _code = TextEditingController();
  final _store = TextEditingController();
  InvitationPreview? _preview;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _store.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      if (_preview == null) {
        final p = await _service.check(_code.text);
        if (!p.usable) {
          setState(() => _error = p.problem);
        } else {
          setState(() {
            _preview = p;
            _store.text = p.storeName ?? '';
          });
        }
        return;
      }
      final user = await _service.accept(_code.text,
          storeName: _preview!.isSeller ? _store.text : null);
      if (!mounted) return;
      final auth = context.read<AuthProvider>();
      Navigator.pop(context);
      auth.updateUser(user);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = _preview;
    return AlertDialog(
      title: const AppText('عندك دعوة كبائع أو موظف؟'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppText(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            if (p == null)
              TextField(
                key: const ValueKey('accept-invitation-code'),
                controller: _code,
                decoration: InputDecoration(
                    labelText: context.tr('رمز أو رابط الدعوة'),
                    helperText:
                        context.tr('الصق الرابط الذي أرسلته لك الإدارة.')),
              )
            else ...[
              AppText(p.isSeller
                  ? 'دعوة لفتح متجر على تريندشام'
                  : 'دعوة للانضمام لفريق تريندشام'),
              if (p.isSeller) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _store,
                  decoration:
                      InputDecoration(labelText: context.tr('اسم المتجر')),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('رجوع')),
        FilledButton(
          onPressed: _busy ? null : _next,
          child: AppText(p == null ? 'تحقق' : 'قبول الدعوة'),
        ),
      ],
    );
  }
}
