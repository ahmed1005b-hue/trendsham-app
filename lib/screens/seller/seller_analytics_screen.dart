import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show NumberFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../widgets/app_state_message.dart';

/// مؤشرات الأداء (نفس صفحة الإحصائيات في لوحة البائع بالموقع):
/// المبيعات وصافي الدخل لفترة يختارها البائع، وحالات الطلبات، وحركة المحفظة، وأفضل المنتجات.
class SellerAnalyticsScreen extends StatefulWidget {
  const SellerAnalyticsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final SellerService? service;

  @override
  State<SellerAnalyticsScreen> createState() => _SellerAnalyticsScreenState();
}

class _SellerAnalyticsScreenState extends State<SellerAnalyticsScreen> {
  late final SellerService _service = widget.service ?? SellerService();
  final _money = NumberFormat.decimalPattern('en');
  int _days = 30;
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.analytics(days: _days);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الإحصائيات.');
    }
  }

  double _num(dynamic v) =>
      (v is num) ? v.toDouble() : double.tryParse('$v') ?? 0;
  String _price(dynamic v) => '${_money.format(_num(v))} ل.س';

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: const AppText('مؤشرات الأداء')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : d == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.emerald,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      _periodPicker(),
                      const SizedBox(height: 12),
                      _kpis(d),
                      const SizedBox(height: 12),
                      _chart(d),
                      _statuses(d),
                      _topProducts(d),
                      _wallet(d),
                    ],
                  ),
                ),
    );
  }

  Widget _periodPicker() {
    return SegmentedButton<int>(
      key: const ValueKey('analytics-days'),
      segments: [
        for (final n in const [7, 14, 30, 90])
          ButtonSegment(
              value: n,
              label: Text(context.tr('آخر :n يوم').replaceAll(':n', '$n'))),
      ],
      selected: {_days},
      showSelectedIcon: false,
      onSelectionChanged: (s) {
        setState(() {
          _days = s.first;
          _data = null;
        });
        _load();
      },
    );
  }

  Widget _kpis(Map<String, dynamic> d) {
    final totals = Map<String, dynamic>.from(d['totals'] ?? {});
    final changes = Map<String, dynamic>.from(d['changes'] ?? {});
    final wallet = Map<String, dynamic>.from(d['wallet'] ?? {});
    final tiles = <(String, String, dynamic)>[
      ('المبيعات', _price(totals['sales']), changes['sales']),
      ('صافي الدخل', _price(totals['net_profit']), changes['net_profit']),
      ('الطلبات', '${totals['orders'] ?? 0}', null),
      ('متوسط الطلب', _price(totals['avg_order_value']), null),
      ('رصيد المحفظة', _price(wallet['balance']), null),
      ('عمولة المنصة', _price(totals['commission']), null),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 1.9,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final (label, value, change) in tiles)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 4),
                  FittedBox(
                    child: AppText(value,
                        style: const TextStyle(
                            fontSize: 17, fontWeight: FontWeight.bold)),
                  ),
                  if (change is num)
                    Text('${change >= 0 ? '▲' : '▼'} ${change.abs()}%',
                        textDirection: TextDirection.ltr,
                        style: TextStyle(
                            fontSize: 11,
                            color: change >= 0
                                ? AppColors.emerald
                                : AppColors.danger)),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _section(String title, Widget child) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 10),
              child,
            ],
          ),
        ),
      );

  Widget _chart(Map<String, dynamic> d) {
    final series = (d['series'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final hasSales = series.any((p) => _num(p['sales']) > 0);
    List<FlSpot> spots(String key) => [
          for (var i = 0; i < series.length; i++)
            FlSpot(i.toDouble(), _num(series[i][key])),
        ];
    LineChartBarData line(String key, Color color) => LineChartBarData(
          spots: spots(key),
          isCurved: true,
          color: color,
          barWidth: 2.5,
          dotData: const FlDotData(show: false),
        );

    return _section(
      'المبيعات وصافي الدخل',
      !hasSales
          ? const AppText('لا مبيعات في هذه الفترة.',
              style: TextStyle(color: AppColors.muted))
          : Column(children: [
              SizedBox(
                height: 180,
                child: LineChart(LineChartData(
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  lineBarsData: [
                    line('sales', AppColors.emerald),
                    line('net_profit', const Color(0xFFC9962C)),
                  ],
                )),
              ),
              const SizedBox(height: 6),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _legend(AppColors.emerald, 'المبيعات'),
                const SizedBox(width: 16),
                _legend(const Color(0xFFC9962C), 'صافي الدخل'),
              ]),
            ]),
    );
  }

  Widget _legend(Color color, String label) => Row(children: [
        Container(width: 12, height: 12, color: color),
        const SizedBox(width: 4),
        AppText(label, style: const TextStyle(fontSize: 12)),
      ]);

  Widget _statuses(Map<String, dynamic> d) {
    final rows = (d['status_breakdown'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    final total = rows.fold<double>(0, (s, r) => s + _num(r['count']));
    return _section(
      'حالات الطلبات',
      Column(children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(children: [
              SizedBox(width: 100, child: AppText('${r['label']}')),
              Expanded(
                child: LinearProgressIndicator(
                  value: total > 0 ? _num(r['count']) / total : 0,
                  color: AppColors.emerald,
                  backgroundColor: AppColors.emerald.withValues(alpha: 0.1),
                  minHeight: 8,
                ),
              ),
              SizedBox(
                  width: 40,
                  child: Text('${r['count']}', textAlign: TextAlign.center)),
            ]),
          ),
      ]),
    );
  }

  Widget _topProducts(Map<String, dynamic> d) {
    final rows = (d['top_products'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return _section(
      'أفضل المنتجات',
      rows.isEmpty
          ? const AppText('لا مبيعات في هذه الفترة.',
              style: TextStyle(color: AppColors.muted))
          : Column(children: [
              for (final r in rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${r['name']}',
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Row(children: [
                    const AppText('الكمية المباعة',
                        style: TextStyle(fontSize: 12)),
                    Text(': ${r['sold_count']}',
                        style: const TextStyle(fontSize: 12)),
                  ]),
                  trailing: AppText(_price(r['revenue']),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
            ]),
    );
  }

  Widget _wallet(Map<String, dynamic> d) {
    final wallet = Map<String, dynamic>.from(d['wallet'] ?? {});
    final rows = (wallet['transactions'] as List? ?? const [])
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
    return _section(
      'حركة المحفظة',
      rows.isEmpty
          ? const AppText('لا توجد حركات على المحفظة بعد.',
              style: TextStyle(color: AppColors.muted))
          : Column(children: [
              for (final r in rows)
                ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: AppText('${r['reason'] ?? ''}',
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${r['date'] ?? ''}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      AppText(_price(r['amount']),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: _num(r['amount']) < 0
                                  ? AppColors.danger
                                  : AppColors.emerald)),
                      AppText(_price(r['balance_after']),
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                    ],
                  ),
                ),
            ]),
    );
  }
}
