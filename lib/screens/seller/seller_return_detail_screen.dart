import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/api_exception.dart';
import '../../services/seller_return_service.dart';
import '../../widgets/app_state_message.dart';
import '../returns/return_detail_body.dart';

/// تفاصيل طلب إرجاع للبائع: موافقة أو رفض (بملاحظة) أو تأكيد الاستلام حسب actions.
class SellerReturnDetailScreen extends StatefulWidget {
  const SellerReturnDetailScreen(
      {super.key, required this.returnId, this.service});

  final int returnId;

  /// قابل للاستبدال في الاختبارات.
  final SellerReturnService? service;

  @override
  State<SellerReturnDetailScreen> createState() =>
      _SellerReturnDetailScreenState();
}

class _SellerReturnDetailScreenState extends State<SellerReturnDetailScreen> {
  late final SellerReturnService _service =
      widget.service ?? SellerReturnService();
  ReturnRequest? _request;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final request = await _service.show(widget.returnId);
      if (mounted) setState(() => _request = request);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل طلب الإرجاع.');
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  /// حوار ملاحظة؛ [noteRequired] يمنع الإرسال بلا نص. الطلب المحدَّث يُعرض عند النجاح.
  Future<void> _decide({
    required String title,
    required String label,
    required String submitLabel,
    required bool noteRequired,
    required String emptyError,
    required String fallbackError,
    required String successMessage,
    required Future<ReturnRequest> Function(String note) action,
  }) async {
    final note = TextEditingController();
    String? error;
    bool submitting = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: AppText(title),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: note,
                  maxLines: 4,
                  maxLength: 2000,
                  decoration: InputDecoration(
                      labelText: ctx.tr(label),
                      border: const OutlineInputBorder()),
                ),
                if (error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: AppText(error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: submitting ? null : () => Navigator.pop(ctx),
                child: const AppText('إلغاء')),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (noteRequired && note.text.trim().isEmpty) {
                        setDialogState(() => error = emptyError);
                        return;
                      }
                      setDialogState(() {
                        error = null;
                        submitting = true;
                      });
                      try {
                        final updated = await action(note.text);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (!mounted) return;
                        setState(() => _request = updated);
                        _toast(successMessage);
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            error = e.message;
                            submitting = false;
                          });
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          setDialogState(() {
                            error = fallbackError;
                            submitting = false;
                          });
                        }
                      }
                    },
              child: AppText(submitLabel),
            ),
          ],
        ),
      ),
    );
    note.dispose();
  }

  Future<void> _approve() => _decide(
        title: 'الموافقة على الإرجاع',
        label: 'ملاحظة للعميل (اختياري)',
        submitLabel: 'إرسال الموافقة',
        noteRequired: false,
        emptyError: '',
        fallbackError: 'تعذّر الموافقة على طلب الإرجاع.',
        successMessage: 'تمت الموافقة على طلب الإرجاع.',
        action: (note) => _service.approve(widget.returnId, note: note),
      );

  Future<void> _reject() => _decide(
        title: 'رفض الإرجاع',
        label: 'سبب الرفض',
        submitLabel: 'إرسال الرفض',
        noteRequired: true,
        emptyError: 'اكتب سبب الرفض.',
        fallbackError: 'تعذّر رفض طلب الإرجاع.',
        successMessage: 'تم رفض طلب الإرجاع.',
        action: (note) => _service.reject(widget.returnId, note: note),
      );

  Future<void> _confirmReceived() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الاستلام'),
        content: const AppText(
            'هل استلمت المنتجات المرتجعة؟ سيتم استرداد المبلغ للعميل بعد التأكيد.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نعم، استلمت المرتجع')),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final updated = await _service.confirmReceived(widget.returnId);
      if (!mounted) return;
      setState(() => _request = updated);
      _toast('تم تأكيد استلام المرتجع.');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر تأكيد استلام المرتجع.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText(_request?.number ?? 'تفاصيل الإرجاع')),
      body: _body(),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final r = _request;
    if (r == null) return const LoadingIndicator();

    return ReturnDetailBody(
      request: r,
      onRefresh: _load,
      actions: [
        if (r.canApprove)
          FilledButton(
            onPressed: _busy ? null : _approve,
            child: const AppText('الموافقة على الإرجاع'),
          ),
        if (r.canReject)
          OutlinedButton(
            onPressed: _busy ? null : _reject,
            child: const AppText('رفض الإرجاع',
                style: TextStyle(color: AppColors.danger)),
          ),
        if (r.canConfirmReceived)
          FilledButton(
            onPressed: _busy ? null : _confirmReceived,
            child: const AppText('تأكيد استلام المرتجع'),
          ),
      ],
    );
  }
}
