import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_review_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// ديون المتاجر للمنصة (نفس صفحة الموقع): متاجر وصّلت بنفسها وحصّلت المال نقداً
/// فبقيت عليها العمولة. يسجّل المدير ما يسدّده المتجر فيعود رصيده.
class AdminDebtsScreen extends StatefulWidget {
  const AdminDebtsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminReviewService? service;

  @override
  State<AdminDebtsScreen> createState() => _AdminDebtsScreenState();
}

class _AdminDebtsScreenState extends State<AdminDebtsScreen> {
  late final AdminReviewService _service =
      widget.service ?? AdminReviewService();
  final _money = NumberFormat.decimalPattern('en');
  StoreDebtsPage? _page;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _service.debts();
      if (mounted) setState(() => _page = page);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل ديون المتاجر.');
    }
  }

  String _price(double v) => '${_money.format(v)} ل.س';

  Future<void> _pay(StoreDebt d) async {
    final message = await showDialog<String>(
        context: context,
        builder: (_) => _PayDebtDialog(debt: d, service: _service));
    if (message == null || !mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('ديون المتاجر')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : page == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const AppText('مجموع ديون المتاجر',
                                  style: TextStyle(
                                      fontSize: 12, color: AppColors.muted)),
                              AppText(_price(page.total),
                                  key: const ValueKey('debts-total'),
                                  style: const TextStyle(
                                      fontSize: 22,
                                      fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              const AppText(
                                  'متاجر وصّلت بنفسها وحصّلت المال نقداً فبقيت عليها عمولة المنصة. عندما يسدّد المتجر سجّل المبلغ هنا.',
                                  style: TextStyle(fontSize: 12)),
                            ],
                          ),
                        ),
                      ),
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: AppStateMessage(
                              message: 'لا توجد ديون على المتاجر.',
                              icon: Icons.check_circle_outline),
                        ),
                      for (final d in page.items)
                        Card(
                          key: ValueKey('debt-${d.sellerProfileId}'),
                          child: ListTile(
                            title: Text(d.storeName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                [d.ownerName, d.phone]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AppText(_price(d.debt),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: page.limit > 0 &&
                                                d.debt >= page.limit
                                            ? AppColors.danger
                                            : null)),
                                const AppText('اضغط للتسديد',
                                    style: TextStyle(
                                        fontSize: 11, color: AppColors.muted)),
                              ],
                            ),
                            onTap: () => _pay(d),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }
}

/// نافذة تسجيل التسديد: تملك حقولها وتعيد رسالة الخادم عند النجاح.
class _PayDebtDialog extends StatefulWidget {
  const _PayDebtDialog({required this.debt, required this.service});

  final StoreDebt debt;
  final AdminReviewService service;

  @override
  State<_PayDebtDialog> createState() => _PayDebtDialogState();
}

class _PayDebtDialogState extends State<_PayDebtDialog> {
  late final _amount =
      TextEditingController(text: widget.debt.debt.toStringAsFixed(0));
  final _note = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = double.tryParse(_amount.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'أدخل أرقام صحيحة.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final message = await widget.service
          .payDebt(widget.debt.sellerProfileId, value, note: _note.text.trim());
      if (mounted) Navigator.pop(context, message);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = e.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'تعذّر الاتصال بالسيرفر.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText('تسجيل تسديد'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.debt.storeName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            TextField(
              key: const ValueKey('debt-amount'),
              controller: _amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: context.tr('المبلغ الذي سدّده'),
                  suffixText: context.tr('ل.س')),
            ),
            TextField(
              controller: _note,
              maxLength: 150,
              decoration: InputDecoration(
                  labelText: context.tr('ملاحظة (مثل: تحويل أو نقداً)')),
            ),
            if (_error != null)
              AppText(_error!, style: const TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: _busy ? null : () => Navigator.pop(context),
            child: const AppText('إلغاء')),
        FilledButton(
          key: const ValueKey('debt-pay-confirm'),
          onPressed: _busy ? null : _save,
          child: const AppText('تسجيل'),
        ),
      ],
    );
  }
}
