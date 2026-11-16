import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../utils/file_share.dart';
import '../../widgets/app_state_message.dart';

/// شريط اختيار الفترة المشترك بين التقارير والمحاسبة.
class DateRangeBar extends StatelessWidget {
  const DateRangeBar({
    super.key,
    required this.from,
    required this.to,
    required this.onChanged,
  });

  final DateTime from;
  final DateTime to;
  final ValueChanged<DateTimeRange> onChanged;

  @override
  Widget build(BuildContext context) {
    final format = DateFormat('yyyy/MM/dd');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: OutlinedButton.icon(
        icon: const Icon(Icons.date_range),
        label: AppText('${format.format(from)} ← ${format.format(to)}'),
        onPressed: () async {
          final range = await showDateRangePicker(
            context: context,
            firstDate: DateTime(2020),
            lastDate: DateTime.now(),
            initialDateRange: DateTimeRange(start: from, end: to),
          );
          if (range != null) onChanged(range);
        },
      ),
    );
  }
}

String formatMoney(num? value) =>
    '${NumberFormat('#,##0.##').format(value ?? 0)} ل.س';

class AdminReportsScreen extends StatefulWidget {
  const AdminReportsScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  State<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends State<AdminReportsScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _report;
  String? _error;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _report = null;
    });
    try {
      final data = await _service.report(_from, _to);
      if (mounted) setState(() => _report = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل التقرير.');
    }
  }

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final bytes = await _service.reportPdf(_from, _to);
      await openPdfBytes(bytes, 'report.pdf');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('التقارير'),
        actions: [
          IconButton(
            tooltip: context.tr('تصدير PDF'),
            onPressed: _exporting || _report == null ? null : _export,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            onChanged: (range) {
              _from = range.start;
              _to = range.end;
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load, color: AppColors.emerald, child: _body()),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final r = _report;
    if (r == null) return const LoadingIndicator();

    final stats = [
      ('عدد الطلبات', '${r['orders_count'] ?? 0}', Icons.receipt_long),
      ('إجمالي المبيعات', formatMoney(r['total_sales']), Icons.trending_up),
      (
        'عمولة المنصة',
        formatMoney(r['total_commission']),
        Icons.account_balance
      ),
      (
        'أرباح البائعين',
        formatMoney(r['total_vendor_earnings']),
        Icons.storefront
      ),
      ('سحوبات معتمدة', formatMoney(r['total_withdrawals']), Icons.payments),
    ];
    final orders = (r['orders'] as List? ?? []).whereType<Map>().toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value, icon) in stats)
              SizedBox(
                width: (MediaQuery.of(context).size.width - 32) / 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(icon, color: AppColors.emerald),
                        const SizedBox(height: 6),
                        AppText(label,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        AppText(value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        AppText('الطلبات المحتسبة',
            style: Theme.of(context).textTheme.titleMedium),
        if (orders.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppText('لا توجد طلبات في هذه الفترة.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (final o in orders)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: AppText('#${o['order_number']} • ${o['customer'] ?? ''}'),
            subtitle:
                AppText(Order.statusLabels[o['status']] ?? '${o['status']}'),
            trailing: AppText(formatMoney(o['total'] as num?),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
      ],
    );
  }
}
