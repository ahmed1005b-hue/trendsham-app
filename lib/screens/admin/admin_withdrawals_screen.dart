import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// تحويل أرباح البائعين: موافقة (خصم من المحفظة) ← تحويل ← تسجيل رقم الحوالة، أو فشل (إرجاع المبلغ).
class AdminWithdrawalsScreen extends StatefulWidget {
  const AdminWithdrawalsScreen({super.key, this.service});
  final AdminService? service;

  @override
  State<AdminWithdrawalsScreen> createState() => _AdminWithdrawalsScreenState();
}

class _AdminWithdrawalsScreenState extends State<AdminWithdrawalsScreen> {
  late final AdminService _service = widget.service ?? AdminService();
  List<dynamic>? _requests;
  String? _error;
  String _status = 'open';

  static const _filters = {
    'open': 'بحاجة لإجراء',
    'pending': 'بانتظار المراجعة',
    'approved': 'بانتظار التحويل',
    'processing': 'لدى البنك',
    'paid': 'تم التحويل',
    'failed': 'فشل',
    'rejected': 'مرفوض',
    'all': 'الكل',
  };

  static const _statusColors = {
    'pending': Color(0xFFB25E00),
    'approved': Color(0xFF1A56DB),
    'processing': Color(0xFF1A56DB),
    'paid': Color(0xFF18794E),
    'failed': AppColors.danger,
    'rejected': AppColors.danger,
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final requests = await _service.withdrawals(status: _status);
      if (mounted) setState(() => _requests = requests);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الطلبات.');
    }
  }

  Future<void> _act(Future<void> Function() action, String success) async {
    try {
      await action();
      _toast(success);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر تنفيذ العملية.');
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(msg)));
  }

  Future<bool> _confirm(String title, String body) async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: AppText(title),
          content: AppText(body),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('متابعة')),
          ],
        ),
      ) ==
      true;

  Future<String?> _askText(String title, String label) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context).translate(label)),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('إلغاء')),
          FilledButton(
            onPressed: () {
              final v = controller.text.trim();
              if (v.isNotEmpty) Navigator.pop(ctx, v);
            },
            child: const AppText('تأكيد'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _markPaid(Map r) async {
    final refController =
        TextEditingController(text: (r['transfer_reference'] ?? '').toString());
    XFile? receipt;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const AppText('تأكيد التحويل'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: refController,
                textDirection: TextDirection.ltr,
                decoration: InputDecoration(
                    labelText: AppLocalizations.of(context)
                        .translate('رقم الحوالة / المرجع البنكي')),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () async {
                  final f = await ImagePicker()
                      .pickImage(source: ImageSource.gallery, imageQuality: 80);
                  if (f != null) setLocal(() => receipt = f);
                },
                icon: Icon(receipt == null
                    ? Icons.receipt_long_outlined
                    : Icons.check_circle_rounded),
                label: AppText(receipt == null
                    ? 'إرفاق صورة الإيصال (اختياري)'
                    : 'تم إرفاق الإيصال'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
              onPressed: () {
                if (refController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx, true);
                }
              },
              child: const AppText('تم التحويل'),
            ),
          ],
        ),
      ),
    );
    final reference = refController.text.trim();
    refController.dispose();
    if (ok != true) return;
    await _act(
        () => _service.markWithdrawalPaid(r['id'] as int, reference,
            receipt: receipt),
        'تم تأكيد التحويل وإشعار البائع.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('تحويل أرباح البائعين')),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              children: [
                for (final e in _filters.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: ChoiceChip(
                      label: AppText(e.value),
                      selected: _status == e.key,
                      onSelected: (_) {
                        setState(() {
                          _status = e.key;
                          _requests = null;
                        });
                        _load();
                      },
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.emerald,
                child: _buildBody()),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_requests == null) return const LoadingIndicator();
    if (_requests!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد طلبات في هذا القسم.',
          icon: Icons.payments_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _requests!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) => _card(_requests![index] as Map),
    );
  }

  Widget _card(Map r) {
    final status = (r['status'] ?? '').toString();
    final color = _statusColors[status] ?? AppColors.muted;
    final amount = double.tryParse(r['amount'].toString()) ?? 0;
    final account = (r['payout_account_number'] ?? '').toString();
    final holder = (r['payout_account_holder_name'] ?? '').toString();
    final id = r['id'] as int;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: AppText(r['vendor_name'] ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                      color: context.softTint(color),
                      borderRadius: BorderRadius.circular(20)),
                  child: AppText((r['status_label'] ?? status).toString(),
                      style: TextStyle(
                          fontSize: 11,
                          color: color,
                          fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            AppText('${amount.toStringAsFixed(0)} ل.س · طلب #$id',
                style: const TextStyle(
                    color: AppColors.emerald,
                    fontSize: 17,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: context.softTint(AppColors.emerald),
                borderRadius: BorderRadius.circular(10),
              ),
              child: account.isEmpty
                  ? const AppText('لا توجد بيانات تحويل محفوظة لهذا الطلب.',
                      style: TextStyle(color: AppColors.danger))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                            '${r['payout_type_label'] ?? ''} · ${r['payout_provider'] ?? ''}',
                            style: const TextStyle(fontSize: 12)),
                        _copyRow(account, ltr: true),
                        _copyRow(holder),
                      ],
                    ),
            ),
            if ((r['transfer_reference'] ?? '').toString().isNotEmpty &&
                status == 'paid')
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child:
                    SelectableText('رقم الحوالة: ${r['transfer_reference']}'),
              ),
            if (status == 'rejected' ||
                status == 'failed' ||
                (r['failure_reason'] ?? '').toString().isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: AppText(
                    (r['admin_note'] ?? r['failure_reason'] ?? '').toString(),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            const SizedBox(height: 8),
            ..._actions(r, status, id, amount, account.isNotEmpty),
          ],
        ),
      ),
    );
  }

  List<Widget> _actions(
      Map r, String status, int id, double amount, bool hasAccount) {
    switch (status) {
      case 'pending':
        return [
          Row(children: [
            Expanded(
              child: FilledButton(
                onPressed: hasAccount
                    ? () async {
                        if (await _confirm('موافقة على السحب',
                            'سيُخصم ${amount.toStringAsFixed(0)} ل.س من محفظة البائع، ثم تحوّل المبلغ وتسجّل رقم الحوالة.')) {
                          await _act(() => _service.approveWithdrawal(id),
                              'تمت الموافقة. حوّل المبلغ ثم سجّل رقم الحوالة.');
                        }
                      }
                    : null,
                child: const AppText('موافقة'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger)),
                onPressed: () async {
                  final note = await _askText('رفض طلب السحب', 'سبب الرفض');
                  if (note != null) {
                    await _act(() => _service.rejectWithdrawal(id, note),
                        'تم رفض الطلب.');
                  }
                },
                child: const AppText('رفض'),
              ),
            ),
          ]),
        ];
      case 'approved':
      case 'processing':
        return [
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(backgroundColor: AppColors.emerald),
              onPressed: () => _markPaid(r),
              icon: const Icon(Icons.price_check_rounded),
              label: const AppText('تم التحويل'),
            ),
          ),
          Row(children: [
            if (status == 'approved')
              TextButton.icon(
                onPressed: () => _act(
                    () => _service.sendWithdrawal(id), 'أُرسلت الحوالة للبنك.'),
                icon: const Icon(Icons.send_rounded, size: 18),
                label: const AppText('إرسال عبر البنك'),
              ),
            const Spacer(),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: AppColors.danger),
              onPressed: () async {
                final reason = await _askText('فشل التحويل', 'سبب فشل التحويل');
                if (reason != null) {
                  await _act(() => _service.markWithdrawalFailed(id, reason),
                      'أُعيد المبلغ لمحفظة البائع.');
                }
              },
              child: const AppText('فشل التحويل'),
            ),
          ]),
        ];
      default:
        return const [];
    }
  }

  Widget _copyRow(String value, {bool ltr = false}) => Row(
        children: [
          Expanded(
            child: SelectableText(value,
                textDirection: ltr ? TextDirection.ltr : null,
                textAlign: ltr ? TextAlign.right : TextAlign.start,
                style: TextStyle(
                    fontWeight: ltr ? FontWeight.w600 : FontWeight.normal,
                    letterSpacing: ltr ? 1 : 0)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.copy_rounded, size: 18),
            tooltip: context.tr('نسخ'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: value));
              _toast('تم النسخ');
            },
          ),
        ],
      );
}
