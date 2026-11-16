import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// تحليلات المنصة الشاملة للمدير — نفس أرقام صفحة الويب (/admin/analytics).
class AdminAnalyticsScreen extends StatefulWidget {
  const AdminAnalyticsScreen({super.key, this.service});

  final AdminService? service;

  @override
  State<AdminAnalyticsScreen> createState() => _AdminAnalyticsScreenState();
}

class _AdminAnalyticsScreenState extends State<AdminAnalyticsScreen> {
  static const windows = [7, 30, 90, 365];

  late final AdminService _service = widget.service ?? AdminService();
  int _days = 30;
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final days = _days;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.analytics(days: days);
      if (!mounted || days != _days) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل التحليلات.');
    } finally {
      if (mounted && days == _days) setState(() => _loading = false);
    }
  }

  void _select(int days) {
    if (days == _days) return;
    setState(() => _days = days);
    _load();
  }

  static String _fmt(dynamic v) {
    final n = (v is num) ? v : num.tryParse('$v') ?? 0;
    final whole = n.round().abs().toString();
    final out = StringBuffer();
    for (var i = 0; i < whole.length; i++) {
      if (i > 0 && (whole.length - i) % 3 == 0) out.write(',');
      out.write(whole[i]);
    }
    return n < 0 ? '-$out' : out.toString();
  }

  Map<String, dynamic> _section(String key) =>
      Map<String, dynamic>.from((_data?[key] as Map?) ?? const {});

  List<Map<String, dynamic>> _list(String key, [Map<String, dynamic>? from]) =>
      (((from ?? _data)?[key] as List?) ?? const [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('تحليلات المنصة')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.emerald,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null && _data == null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_data == null) return const LoadingIndicator();

    final k = _section('kpis');
    final c = _section('changes');
    final u = _section('users');
    final cat = _section('catalog');
    final r = _section('returns');
    final f = _section('finance');
    final m = _section('marketing');
    final s = _section('support');

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final d in windows)
              ChoiceChip(
                label: AppText('آخر $d يوم'),
                selected: _days == d,
                onSelected: _loading ? null : (_) => _select(d),
              ),
          ],
        ),
        if (_loading) const LinearProgressIndicator(minHeight: 2),
        const SizedBox(height: 12),
        _grid([
          _Stat(Icons.trending_up, 'إجمالي المبيعات', _fmt(k['gmv']),
              money: true, change: c['gmv']),
          _Stat(Icons.receipt_long, 'الطلبات', _fmt(k['orders']),
              change: c['orders']),
          _Stat(Icons.account_balance, 'عمولة المنصة', _fmt(k['commission']),
              money: true, change: c['commission']),
          _Stat(Icons.person_add_alt, 'عملاء جدد', _fmt(k['new_customers']),
              change: c['new_customers']),
          _Stat(Icons.shopping_basket_outlined, 'متوسط الطلب',
              _fmt(k['avg_order_value']),
              money: true),
          _Stat(Icons.replay, 'مبالغ مستردة', _fmt(k['refunded']),
              money: true),
          _Stat(Icons.cancel_outlined, 'نسبة الإلغاء', '${k['cancel_rate']}%'),
          _Stat(Icons.assignment_return_outlined, 'نسبة الإرجاع',
              '${r['return_rate']}%'),
        ]),
        _title(Icons.show_chart, 'المبيعات والعمولة'),
        _card(SizedBox(height: 200, child: _salesChart())),
        _title(Icons.donut_large, 'حالات الطلبات'),
        _card(_bars(_list('order_status'), 'label', 'count')),
        _title(Icons.credit_card, 'طرق الدفع'),
        _card(_bars(_list('payment_methods'), 'label', 'amount', money: true)),
        _title(Icons.storefront, 'أفضل المتاجر'),
        _card(_ranking(_list('top_sellers'), 'name', 'sales')),
        _title(Icons.emoji_events_outlined, 'أكثر المنتجات مبيعاً'),
        _card(_ranking(_list('top_products'), 'name', 'revenue')),
        _title(Icons.category_outlined, 'أفضل الأقسام'),
        _card(_bars(_list('top_categories'), 'name', 'revenue', money: true)),
        _title(Icons.people_outline, 'المستخدمون'),
        _grid([
          _Stat(Icons.person_outline, 'العملاء', _fmt(u['customers'])),
          _Stat(Icons.shopping_cart_checkout, 'مشترون نشطون',
              _fmt(u['active_buyers'])),
          _Stat(Icons.repeat, 'مشترون متكررون', _fmt(u['repeat_buyers'])),
          _Stat(Icons.store_mall_directory_outlined, 'المتاجر المعتمدة',
              _fmt(u['sellers'])),
          _Stat(Icons.hourglass_top, 'طلبات متاجر معلّقة',
              _fmt(u['pending_sellers'])),
          _Stat(Icons.block, 'متاجر موقوفة', _fmt(u['suspended_sellers'])),
        ]),
        _title(Icons.inventory_2_outlined, 'المنتجات'),
        _grid([
          _Stat(Icons.inventory, 'منتجات منشورة', _fmt(cat['active_products'])),
          _Stat(Icons.fact_check_outlined, 'بانتظار المراجعة',
              _fmt(cat['pending_review'])),
          _Stat(Icons.warning_amber, 'مخزون منخفض', _fmt(cat['low_stock'])),
          _Stat(Icons.remove_shopping_cart_outlined, 'نفد من المخزون',
              _fmt(cat['out_of_stock'])),
        ]),
        _title(Icons.assignment_return_outlined, 'المرتجعات'),
        _grid([
          _Stat(Icons.inbox_outlined, 'طلبات إرجاع في الفترة',
              _fmt(r['total'])),
          _Stat(Icons.notifications_active_outlined, 'تنتظر الإدارة',
              _fmt(r['needs_action'])),
        ]),
        _card(_bars(_list('by_reason', r), 'label', 'count')),
        _title(Icons.payments_outlined, 'المال'),
        _grid([
          _Stat(Icons.account_balance_wallet_outlined, 'أرصدة محافظ البائعين',
              _fmt(f['wallets_balance']),
              money: true),
          _Stat(Icons.pending_actions, 'سحوبات معلّقة',
              _fmt(f['pending_withdrawals_amount']),
              money: true),
          _Stat(Icons.price_check, 'سحوبات مدفوعة',
              _fmt(f['paid_withdrawals_amount']),
              money: true),
          _Stat(Icons.campaign_outlined, 'إيراد الإعلانات',
              _fmt((f['showcase_revenue'] ?? 0) + (f['story_revenue'] ?? 0)),
              money: true),
        ]),
        _title(Icons.auto_awesome_outlined, 'التسويق والولاء'),
        _grid([
          _Stat(Icons.confirmation_number_outlined, 'استخدامات الكوبونات',
              _fmt(m['coupon_redemptions'])),
          _Stat(Icons.percent, 'قيمة الخصومات', _fmt(m['coupon_discount']),
              money: true),
          _Stat(Icons.diamond_outlined, 'نقاط مكتسبة',
              _fmt(m['points_earned'])),
          _Stat(Icons.redeem, 'نقاط مستبدلة', _fmt(m['points_redeemed'])),
        ]),
        _title(Icons.support_agent, 'الدعم'),
        _grid([
          _Stat(Icons.chat_outlined, 'رسائل بائعين مفتوحة',
              _fmt(s['open_seller_tickets'])),
          _Stat(Icons.smart_toy_outlined, 'محادثات محوّلة للإدارة',
              _fmt(s['escalated_chats'])),
          _Stat(Icons.help_outline, 'أسئلة منتجات بلا جواب',
              _fmt(s['unanswered_questions'])),
        ]),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _title(IconData icon, String text) => Padding(
        padding: const EdgeInsetsDirectional.only(top: 16, bottom: 8),
        child: Row(children: [
          Icon(icon, size: 20, color: AppColors.gold),
          const SizedBox(width: 6),
          Expanded(
            child: AppText(text,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ]),
      );

  Widget _card(Widget child) => Card(
        margin: EdgeInsets.zero,
        child: Padding(padding: const EdgeInsets.all(12), child: child),
      );

  Widget _grid(List<_Stat> stats) => GridView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          mainAxisExtent: 112,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemCount: stats.length,
        itemBuilder: (_, i) => _StatCard(stat: stats[i]),
      );

  Widget _empty() => const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: AppText('لا توجد بيانات في هذه الفترة.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );

  /// أشرطة أفقية نسبية (القيمة من الحقل valueKey والاسم من الخادم مترجماً).
  Widget _bars(List<Map<String, dynamic>> rows, String labelKey, String valueKey,
      {bool money = false}) {
    final values = rows.map((e) => (e[valueKey] as num?) ?? 0).toList();
    final max = values.fold<num>(0, (a, b) => b > a ? b : a);
    if (rows.isEmpty || max == 0) return _empty();
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text('${rows[i][labelKey] ?? ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ),
                  Text(_fmt(values[i]),
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.bold)),
                  if (money) ...[
                    const SizedBox(width: 4),
                    const AppText('ل.س',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                  ],
                ]),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: values[i] / max,
                    minHeight: 6,
                    color: AppColors.emerald,
                    backgroundColor: AppColors.border,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _ranking(
      List<Map<String, dynamic>> rows, String labelKey, String valueKey) {
    if (rows.isEmpty) return _empty();
    return Column(
      children: [
        for (var i = 0; i < rows.length; i++)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              radius: 13,
              backgroundColor: AppColors.emerald.withValues(alpha: .12),
              child: Text('${i + 1}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.emerald)),
            ),
            title: Text('${rows[i][labelKey] ?? ''}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(_fmt(rows[i][valueKey]),
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(width: 4),
              const AppText('ل.س',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
            ]),
          ),
      ],
    );
  }

  Widget _salesChart() {
    final series = _list('series');
    final gmv = <FlSpot>[];
    final commission = <FlSpot>[];
    for (var i = 0; i < series.length; i++) {
      gmv.add(FlSpot(i.toDouble(), ((series[i]['gmv'] as num?) ?? 0).toDouble()));
      commission.add(FlSpot(
          i.toDouble(), ((series[i]['commission'] as num?) ?? 0).toDouble()));
    }
    if (gmv.every((p) => p.y == 0)) return _empty();

    LineChartBarData line(List<FlSpot> spots, Color color) => LineChartBarData(
          spots: spots,
          isCurved: true,
          curveSmoothness: 0.3,
          color: color,
          barWidth: 2.2,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(
              show: true, color: color.withValues(alpha: .10)),
        );

    final step = (series.length / 4).ceilToDouble();
    return LineChart(LineChartData(
      gridData: const FlGridData(show: true, drawVerticalLine: false),
      borderData: FlBorderData(show: false),
      titlesData: FlTitlesData(
        leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles:
            const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 22,
            interval: step > 0 ? step : 1,
            getTitlesWidget: (value, meta) {
              final i = value.toInt();
              if (i < 0 || i >= series.length) return const SizedBox.shrink();
              final date = '${series[i]['date'] ?? ''}';
              return Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(date.length >= 10 ? date.substring(5) : date,
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.muted)),
              );
            },
          ),
        ),
      ),
      lineBarsData: [
        line(gmv, AppColors.emerald),
        line(commission, AppColors.gold),
      ],
    ));
  }
}

class _Stat {
  const _Stat(this.icon, this.label, this.value, {this.money = false, this.change});

  final IconData icon;
  final String label;
  final String value;
  final bool money;
  final dynamic change;
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.stat});

  final _Stat stat;

  @override
  Widget build(BuildContext context) {
    final change = stat.change is num ? stat.change as num : null;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(stat.icon, size: 18, color: AppColors.emerald),
              const SizedBox(width: 6),
              Expanded(
                child: AppText(stat.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        color: AppColors.muted, fontSize: 12, height: 1.2)),
              ),
            ]),
            const Spacer(),
            Row(children: [
              Flexible(
                child: Text(stat.value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              if (stat.money) ...[
                const SizedBox(width: 4),
                const AppText('ل.س',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ]),
            if (change != null)
              Text(
                '${change > 0 ? '▲' : change < 0 ? '▼' : '•'} ${change.abs().round()}%',
                textDirection: TextDirection.ltr,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: change > 0
                      ? AppColors.emerald
                      : change < 0
                          ? AppColors.danger
                          : AppColors.muted,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
