import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';
import '../../services/admin_review_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/text_prompt_dialog.dart';
import '../returns/return_detail_body.dart';

/// المرتجعات للمدير (نفس صفحة الموقع): المحالة للإدارة، وبانتظار الاسترداد، والكل.
class AdminReturnsScreen extends StatefulWidget {
  const AdminReturnsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminReviewService? service;

  @override
  State<AdminReturnsScreen> createState() => _AdminReturnsScreenState();
}

class _AdminReturnsScreenState extends State<AdminReturnsScreen> {
  late final AdminReviewService _service =
      widget.service ?? AdminReviewService();
  String _tab = 'escalated';
  AdminReturnsPage? _page;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _service.returns(tab: _tab);
      if (mounted) setState(() => _page = page);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المرتجعات.');
    }
  }

  Future<void> _open(ReturnRequest r) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            AdminReturnDetailScreen(returnId: r.id, service: _service)));
    if (mounted) _load();
  }

  Widget _tabLabel(String label, int? count) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [AppText(label), Text(' (${count ?? 0})')],
      );

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('المرتجعات')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              key: const ValueKey('returns-tabs'),
              showSelectedIcon: false,
              segments: [
                ButtonSegment(
                    value: 'escalated',
                    label: _tabLabel('للإدارة', page?.escalated)),
                ButtonSegment(
                    value: 'awaiting_refund',
                    label: _tabLabel('للاسترداد', page?.awaitingRefund)),
                const ButtonSegment(value: 'all', label: AppText('الكل')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) {
                setState(() => _tab = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: _error != null
                ? AppStateMessage(
                    message: _error!, icon: Icons.error_outline, onRetry: _load)
                : page == null
                    ? const LoadingIndicator()
                    : page.items.isEmpty
                        ? const AppStateMessage(
                            message: 'لا توجد طلبات إرجاع هنا.',
                            icon: Icons.assignment_return_outlined)
                        : RefreshIndicator(
                            onRefresh: _load,
                            color: AppColors.primary,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                              itemCount: page.items.length,
                              itemBuilder: (_, i) {
                                final r = page.items[i];
                                return Card(
                                  key: ValueKey('admin-return-${r.id}'),
                                  child: ListTile(
                                    onTap: () => _open(r),
                                    title: Text(r.number,
                                        textDirection: TextDirection.ltr,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.bold)),
                                    subtitle: Text(
                                        [r.storeName, r.customerName]
                                            .whereType<String>()
                                            .join(' ← '),
                                        style: const TextStyle(fontSize: 12)),
                                    trailing: Chip(
                                      label: AppText(r.statusLabel,
                                          style: const TextStyle(fontSize: 11)),
                                      visualDensity: VisualDensity.compact,
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}

/// تفاصيل طلب إرجاع للمدير: حكم في المحال للإدارة، وتأكيد الاستلام، وتسجيل الاسترداد.
class AdminReturnDetailScreen extends StatefulWidget {
  const AdminReturnDetailScreen(
      {super.key, required this.returnId, this.service});

  final int returnId;
  final AdminReviewService? service;

  @override
  State<AdminReturnDetailScreen> createState() =>
      _AdminReturnDetailScreenState();
}

class _AdminReturnDetailScreenState extends State<AdminReturnDetailScreen> {
  late final AdminReviewService _service =
      widget.service ?? AdminReviewService();
  AdminReturn? _data;
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
      final data = await _service.showReturn(widget.returnId);
      if (mounted) setState(() => _data = data);
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

  Future<void> _run(Future<AdminReturn> Function() action, String done) async {
    setState(() => _busy = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _data = updated);
      _toast(done);
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } catch (_) {
      if (mounted) _toast('تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// ملاحظة اختيارية أو مطلوبة قبل الحكم.
  Future<String?> _askNote(String title, String label, bool required) =>
      showTextPrompt(context,
          title: title,
          label: label,
          required: required,
          emptyError: 'اكتب سبب الرفض.',
          fieldKey: const ValueKey('return-note'),
          sendKey: const ValueKey('return-note-send'));

  Future<void> _approve() async {
    final note = await _askNote(
        'الموافقة على الإرجاع', 'ملاحظة للعميل (اختياري)', false);
    if (note == null) return;
    await _run(() => _service.approveReturn(widget.returnId, note: note),
        'تمت الموافقة على طلب الإرجاع.');
  }

  Future<void> _reject() async {
    final note = await _askNote('رفض الإرجاع', 'سبب الرفض', true);
    if (note == null) return;
    await _run(() => _service.rejectReturn(widget.returnId, note: note),
        'تم رفض طلب الإرجاع.');
  }

  Future<void> _received() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: const AppText('تأكيد استلام المنتجات المرتجعة؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نعم، استلمت المرتجع')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _service.confirmReceived(widget.returnId),
        'تم تأكيد استلام المرتجع.');
  }

  Future<void> _refund(AdminReturn d) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _RefundSheet(
          data: d,
          service: _service,
          returnId: widget.returnId,
          onDone: (updated) => _data = updated),
    );
    if (saved == true && mounted) {
      setState(() {});
      _toast('تم تسجيل الاسترداد.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: AppText(d?.request.number ?? 'تفاصيل الإرجاع')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : d == null
              ? const LoadingIndicator()
              : ReturnDetailBody(
                  request: d.request,
                  onRefresh: _load,
                  actions: [
                    if (d.canDecide) ...[
                      FilledButton(
                        key: const ValueKey('admin-return-approve'),
                        onPressed: _busy ? null : _approve,
                        child: const AppText('الموافقة على الإرجاع'),
                      ),
                      OutlinedButton(
                        key: const ValueKey('admin-return-reject'),
                        onPressed: _busy ? null : _reject,
                        child: const AppText('رفض الإرجاع',
                            style: TextStyle(color: AppColors.danger)),
                      ),
                    ],
                    if (d.canConfirmReceived)
                      FilledButton(
                        key: const ValueKey('admin-return-received'),
                        onPressed: _busy ? null : _received,
                        child: const AppText('تأكيد استلام المرتجع'),
                      ),
                    if (d.canRecordRefund)
                      FilledButton(
                        key: const ValueKey('admin-return-refund'),
                        onPressed: _busy ? null : () => _refund(d),
                        child: const AppText('تسجيل الاسترداد'),
                      ),
                  ],
                ),
    );
  }
}

class _RefundSheet extends StatefulWidget {
  const _RefundSheet(
      {required this.data,
      required this.service,
      required this.returnId,
      required this.onDone});

  final AdminReturn data;
  final AdminReviewService service;
  final int returnId;
  final ValueChanged<AdminReturn> onDone;

  @override
  State<_RefundSheet> createState() => _RefundSheetState();
}

class _RefundSheetState extends State<_RefundSheet> {
  late final _amount = TextEditingController(
      text: widget.data.suggestedAmount.toStringAsFixed(0));
  final _reference = TextEditingController();
  final _extra = TextEditingController();
  final _note = TextEditingController();
  late String? _method = widget.data.giftBalanceUsed > 0 &&
          widget.data.methods.any((m) => m.$1 == 'gift_balance')
      ? 'gift_balance'
      : (widget.data.methods.isEmpty ? null : widget.data.methods.first.$1);
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    _reference.dispose();
    _extra.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.trim());
    if (amount == null || amount <= 0 || _method == null) {
      setState(() => _error = 'أدخل أرقام صحيحة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final updated = await widget.service.recordRefund(
        widget.returnId,
        amount: amount,
        method: _method!,
        reference: _reference.text.trim(),
        note: _note.text.trim(),
        extraShipping: double.tryParse(_extra.text.trim()),
      );
      widget.onDone(updated);
      if (mounted) Navigator.pop(context, true);
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
    final d = widget.data;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('تسجيل الاسترداد',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
            const AppText('سجّل المبلغ الذي دفعته للعميل خارج النظام.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: AppText(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            TextField(
              key: const ValueKey('refund-amount'),
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  InputDecoration(labelText: context.tr('المبلغ (ل.س)')),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _method,
              decoration:
                  InputDecoration(labelText: context.tr('طريقة الاسترداد')),
              items: [
                for (final (value, label) in d.methods)
                  DropdownMenuItem(value: value, child: AppText(label)),
              ],
              onChanged: (v) => setState(() => _method = v),
            ),
            TextField(
              controller: _reference,
              maxLength: 255,
              decoration: InputDecoration(labelText: context.tr('المرجع')),
            ),
            TextField(
              controller: _extra,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.tr('شحن إضافي (ل.س) — اختياري'),
                helperText: d.maxExtraShipping > 0
                    ? '≤ ${d.maxExtraShipping.toStringAsFixed(0)}'
                    : null,
              ),
            ),
            TextField(
              controller: _note,
              maxLines: 2,
              maxLength: 2000,
              decoration: InputDecoration(
                  labelText: context.tr('ملاحظة (مطلوبة عند إضافة شحن)')),
            ),
            const SizedBox(height: 8),
            FilledButton(
              key: const ValueKey('refund-save'),
              onPressed: _busy ? null : _save,
              child: const AppText('تسجيل الاسترداد'),
            ),
          ],
        ),
      ),
    );
  }
}
