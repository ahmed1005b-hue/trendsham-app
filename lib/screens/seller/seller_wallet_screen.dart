import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/seller_profile.dart';
import '../../services/admin_service.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:pdf/pdf.dart';
import 'seller_payment_methods_screen.dart';
import 'seller_shipping_settings_screen.dart';

class SellerWalletScreen extends StatefulWidget {
  final int? sellerId;
  final String? sellerName;

  const SellerWalletScreen({
    super.key,
    this.sellerId,
    this.sellerName,
  });

  @override
  State<SellerWalletScreen> createState() => _SellerWalletScreenState();
}

class _SellerWalletScreenState extends State<SellerWalletScreen> {
  final SellerService _service = SellerService();
  final AdminService _adminService = AdminService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loadingMore = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = widget.sellerId == null
          ? await _service.wallet()
          : await _adminService.sellerWallet(widget.sellerId!);
      setState(() => _data = data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'تعذّر تحميل المحفظة: $e');
    }
  }

  Future<void> _loadMore() async {
    if (_data == null || _loadingMore) return;
    final nextPage = (_data!['current_page'] as int) + 1;
    if (nextPage > (_data!['last_page'] as int)) return;

    setState(() => _loadingMore = true);
    try {
      final nextData = widget.sellerId == null
          ? await _service.wallet(page: nextPage)
          : await _adminService.sellerWallet(widget.sellerId!, page: nextPage);
      if (!mounted) return;
      setState(() {
        _data = {
          ..._data!,
          ...nextData,
          'transactions': [
            ..._data!['transactions'] as List<WalletTransactionModel>,
            ...nextData['transactions'] as List<WalletTransactionModel>,
          ],
        };
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('تعذّر تحميل كشف الحساب: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _showWithdrawDialog() async {
    final controller = TextEditingController();

    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('طلب سحب أرباح'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppText(
              _data?['default_method'] is Map
                  ? 'سيُحوَّل المبلغ إلى: ${_data!['default_method']['provider']} ${_data!['default_method']['masked_number']}'
                  : 'أضف طريقة استلام أولاً من أيقونة البطاقة أعلى الشاشة.',
              style: const TextStyle(fontSize: 13, color: AppColors.muted),
            ),
            if (((_data?['min_withdrawal'] ?? 0) as num) > 0)
              AppText(
                'أقل مبلغ للسحب: ${(_data!['min_withdrawal'] as num).toStringAsFixed(0)} ل.س',
                style: const TextStyle(fontSize: 12, color: AppColors.muted),
              ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context).translate('المبلغ (ل.س)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              final amount = double.tryParse(controller.text);
              if (amount == null || amount <= 0) return;

              try {
                await _service.requestWithdrawal(amount);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: AppText(
                            'تم إرسال طلب السحب، بانتظار موافقة الإدارة.')),
                  );
                }
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: AppText(e.message)));
                }
              }
            },
            child: const AppText('إرسال'),
          ),
        ],
      ),
    );
  }

  Future<void> _exportStatement() async {
    if (_data == null) return;
    final balance = _data!['balance'] ?? 0;
    final transactions = _data!['transactions'] as List<WalletTransactionModel>;

    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TRENDSHAM - Wallet Statement',
                      style: pw.TextStyle(
                          fontSize: 18, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                      'Date: ${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
                      style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
              pw.SizedBox(height: 14),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey200,
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Current Balance:',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    pw.Text('${balance.toStringAsFixed(0)} SYP',
                        style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold, fontSize: 16)),
                  ],
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text('Transactions History:',
                  style: pw.TextStyle(
                      fontSize: 14, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 8),
              ...transactions.map((tx) => pw.Container(
                    margin: const pw.EdgeInsets.only(bottom: 6),
                    padding: const pw.EdgeInsets.all(8),
                    decoration: pw.BoxDecoration(
                      border:
                          pw.Border.all(color: PdfColors.grey400, width: 0.5),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Text(
                                tx.type == 'credit' ? 'Deposit' : 'Withdrawal',
                                style: pw.TextStyle(
                                    fontWeight: pw.FontWeight.bold,
                                    fontSize: 12)),
                            pw.SizedBox(height: 2),
                            pw.Text(
                                tx.createdAt != null
                                    ? DateFormat('yyyy-MM-dd HH:mm')
                                        .format(tx.createdAt!.toLocal())
                                    : '',
                                style: const pw.TextStyle(
                                    fontSize: 9, color: PdfColors.grey700)),
                          ],
                        ),
                        pw.Text(
                          '${tx.type == 'credit' ? '+' : '-'}${tx.amount.toStringAsFixed(0)} SYP',
                          style: pw.TextStyle(
                            fontWeight: pw.FontWeight.bold,
                            fontSize: 12,
                            color: tx.type == 'credit'
                                ? PdfColors.green700
                                : PdfColors.red700,
                          ),
                        ),
                      ],
                    ),
                  )),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      onLayout: (format) async => pdf.save(),
      name: 'statement.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(widget.sellerId == null
            ? 'محفظتي'
            : 'كشف حساب ${widget.sellerName ?? ''}'),
        actions: [
          IconButton(
            tooltip: context.tr('تصدير كشف الحساب PDF'),
            icon: const Icon(Icons.picture_as_pdf_rounded),
            onPressed: _exportStatement,
          ),
          IconButton(
            tooltip: context.tr('طرق الدفع'),
            icon: const Icon(Icons.credit_card),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const SellerPaymentMethodsScreen(),
              ),
            ),
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: AppColors.danger),
              const SizedBox(height: 12),
              AppText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _load,
                child: const AppText('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.emerald),
      );
    }

    final transactions = _data!['transactions'] as List<WalletTransactionModel>;
    final locale = Localizations.localeOf(context).toString();

    final balance = (_data!['balance'] as num?)?.toDouble() ?? 0;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // رصيد بالسالب = دين للمنصة (عمولات طلبات وصّلها بنفسه وحصّل ثمنها نقداً)
        if (balance < 0)
          Card(
            key: const ValueKey('wallet-debt'),
            color: const Color(0xFFFFF4E0),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Color(0xFFC9962C)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          context.tr('عليك :amount ل.س للمنصة.').replaceAll(
                              ':amount',
                              NumberFormat.decimalPattern('en')
                                  .format(-balance)),
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        const AppText(
                            'هذه عمولات طلبات وصّلتها بنفسك وحصّلت ثمنها نقداً. تُخصم تلقائياً من مبيعاتك القادمة، أو سدّدها للإدارة.',
                            style: TextStyle(fontSize: 13)),
                        TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                  builder: (_) =>
                                      const SellerShippingSettingsScreen())),
                          child: const AppText('إعدادات الشحن'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const AppText('الرصيد الحالي',
                    style: TextStyle(color: AppColors.muted)),
                const SizedBox(height: 4),
                AppText(
                  '${_data!['balance'].toStringAsFixed(0)} ل.س',
                  style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emeraldDark),
                ),
                const SizedBox(height: 12),
                if (widget.sellerId == null)
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                        onPressed: _showWithdrawDialog,
                        child: const AppText('طلب سحب')),
                  ),
                if (_data!['pending_withdrawals'] > 0) ...[
                  const SizedBox(height: 8),
                  AppText(
                    'لديك ${_data!['pending_withdrawals'].toStringAsFixed(0)} ل.س ضمن طلبات سحب معلّقة',
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
                if (widget.sellerId == null && _data!['available'] != null) ...[
                  const SizedBox(height: 4),
                  AppText(
                    'المتاح للسحب الآن: ${(_data!['available'] as double).toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.emerald,
                        fontWeight: FontWeight.w600),
                  ),
                ],
                // أرباح طلبات ما زالت في مدة الإرجاع: في الرصيد لكنها لا تُسحب بعد
                if (widget.sellerId == null &&
                    ((_data!['held_for_returns'] as double?) ?? 0) > 0) ...[
                  const SizedBox(height: 4),
                  AppText(
                    'محجوز حتى تنتهي مدة الإرجاع: ${(_data!['held_for_returns'] as double).toStringAsFixed(0)} ل.س',
                    key: const ValueKey('wallet-held-for-returns'),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (widget.sellerId == null &&
            (_data!['recent_withdrawals'] as List?)?.isNotEmpty == true) ...[
          const SizedBox(height: 20),
          const AppText('طلبات السحب',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          for (final w in (_data!['recent_withdrawals'] as List)
              .cast<Map<String, dynamic>>())
            _withdrawalTile(w),
        ],
        const SizedBox(height: 20),
        const AppText('كشف الحساب - سجل الحركات',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (transactions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: AppText('لا يوجد حركات بعد.',
                style: TextStyle(color: AppColors.muted)),
          )
        else
          ...transactions.map((tx) {
            final isCredit = tx.type == 'credit';
            final color = isCredit ? AppColors.emerald : AppColors.danger;
            final date = tx.createdAt == null
                ? '—'
                : DateFormat('yyyy-MM-dd HH:mm', locale)
                    .format(tx.createdAt!.toLocal());

            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      isCredit ? Icons.arrow_downward : Icons.arrow_upward,
                      color: color,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: AppText(
                                  tx.reasonLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold),
                                ),
                              ),
                              const SizedBox(width: 8),
                              AppText(
                                isCredit ? 'إيداع' : 'سحب',
                                style: TextStyle(
                                  color: color,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          _statementDetail(
                            'المبلغ',
                            '${tx.amount.toStringAsFixed(0)} ل.س',
                            valueColor: color,
                          ),
                          const SizedBox(height: 2),
                          _statementDetail(
                            'الرصيد بعد الحركة',
                            '${tx.balanceAfter.toStringAsFixed(0)} ل.س',
                          ),
                          const SizedBox(height: 2),
                          _statementDetail('التاريخ', date),
                          if (tx.note != null && tx.note!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            AppText(
                              tx.note!,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.muted),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }),
        if ((_data!['current_page'] as int) < (_data!['last_page'] as int))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: OutlinedButton(
              onPressed: _loadingMore ? null : _loadMore,
              child: _loadingMore
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const AppText('تحميل المزيد'),
            ),
          ),
      ],
    );
  }

  static const _wdColors = {
    'pending': Color(0xFFB25E00),
    'approved': Color(0xFF1A56DB),
    'processing': Color(0xFF1A56DB),
    'paid': Color(0xFF18794E),
    'failed': AppColors.danger,
    'rejected': AppColors.danger,
  };

  Widget _withdrawalTile(Map<String, dynamic> w) {
    final status = (w['status'] ?? '').toString();
    final color = _wdColors[status] ?? AppColors.muted;
    final amount = double.tryParse((w['amount'] ?? 0).toString()) ?? 0;
    final note = status == 'paid'
        ? 'رقم الحوالة: ${w['transfer_reference'] ?? '—'}'
        : status == 'rejected'
            ? (w['admin_note'] ?? '').toString()
            : status == 'failed'
                ? (w['failure_reason'] ?? '').toString()
                : '${w['payout_provider'] ?? ''} ${w['masked_account'] ?? ''}';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: context.softTint(color),
          child: Icon(
              status == 'paid'
                  ? Icons.check_circle_rounded
                  : (status == 'failed' || status == 'rejected')
                      ? Icons.cancel_rounded
                      : Icons.schedule_rounded,
              color: color),
        ),
        title: AppText('${amount.toStringAsFixed(0)} ل.س',
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: note.trim().isEmpty
            ? null
            : SelectableText(note, style: const TextStyle(fontSize: 12)),
        trailing: AppText((w['status_label'] ?? status).toString(),
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _statementDetail(String label, String value, {Color? valueColor}) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppText(
          label,
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
        const AppText(': '),
        Expanded(
          child: AppText(
            value,
            style: TextStyle(
              fontSize: 12,
              color: valueColor ?? AppColors.muted,
              fontWeight:
                  valueColor == null ? FontWeight.normal : FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
