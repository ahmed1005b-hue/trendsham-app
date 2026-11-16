import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';

/// بطاقة مخطط المبيعات (أسبوعي 14 يوم / شهري 12 شهر) مع تبديل بين الوضعين.
class SalesChartCard extends StatefulWidget {
  final List<Map<String, dynamic>> weeklySales;
  final List<Map<String, dynamic>> monthlySales;
  final double? monthlyGrowth;
  const SalesChartCard({
    super.key,
    required this.weeklySales,
    required this.monthlySales,
    this.monthlyGrowth,
  });

  @override
  State<SalesChartCard> createState() => _SalesChartCardState();
}

class _SalesChartCardState extends State<SalesChartCard> {
  bool _monthly = false;

  List<FlSpot> _spots() {
    final data = _monthly ? widget.monthlySales : widget.weeklySales;
    final spots = <FlSpot>[];
    for (var i = 0; i < data.length; i++) {
      final total = double.tryParse('${data[i]['total'] ?? 0}') ?? 0.0;
      spots.add(FlSpot(i.toDouble(), total));
    }
    return spots;
  }

  String _label(int index) {
    final data = _monthly ? widget.monthlySales : widget.weeklySales;
    if (index < 0 || index >= data.length) return '';
    final date = '${data[index]['date'] ?? ''}';
    if (_monthly) {
      // 2026-03 -> آذار/مارس بالرقم فقط
      final parts = date.split('-');
      return parts.length == 2 ? parts[1] : date;
    }
    // 2026-03-15 -> 15
    final parts = date.split('-');
    return parts.length == 3 ? parts[2] : date;
  }

  @override
  Widget build(BuildContext context) {
    final spots = _spots();
    final maxVal = spots.isEmpty
        ? 0.0
        : spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final maxY = maxVal == 0 ? 1.0 : maxVal * 1.2;
    final growth = widget.monthlyGrowth;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.insights, color: AppColors.emerald, size: 20),
              const SizedBox(width: 8),
              const Expanded(
                child: AppText(
                  'مخطط المبيعات',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ),
              if (growth != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: growth >= 0
                        ? AppColors.emerald.withValues(alpha: .12)
                        : AppColors.danger.withValues(alpha: .1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        growth >= 0 ? Icons.trending_up : Icons.trending_down,
                        size: 14,
                        color:
                            growth >= 0 ? AppColors.emerald : AppColors.danger,
                      ),
                      const SizedBox(width: 3),
                      AppText(
                        '${growth.abs().toStringAsFixed(0)}%',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: growth >= 0
                              ? AppColors.emerald
                              : AppColors.danger,
                        ),
                      ),
                    ],
                  ),
                ),
              const SizedBox(width: 8),
              // مبدّل أسبوعي/شهري
              Container(
                decoration: BoxDecoration(
                  color: AppColors.bgLight,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    _toggleButton('أسبوعي', !_monthly, () {
                      setState(() => _monthly = false);
                    }),
                    _toggleButton('شهري', _monthly, () {
                      setState(() => _monthly = true);
                    }),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 180,
            child: spots.isEmpty || spots.every((s) => s.y == 0)
                ? const Center(
                    child: AppText(
                      'لا توجد بيانات كافية بعد.',
                      style: TextStyle(color: AppColors.muted),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: (maxY / 4) > 0 ? (maxY / 4) : 1.0,
                        getDrawingHorizontalLine: (v) => const FlLine(
                          color: AppColors.border,
                          strokeWidth: 0.6,
                          dashArray: [4, 4],
                        ),
                      ),
                      titlesData: FlTitlesData(
                        leftTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: (spots.length / 5).ceilToDouble() > 0
                                ? (spots.length / 5).ceilToDouble()
                                : 1.0,
                            reservedSize: 22,
                            getTitlesWidget: (value, meta) {
                              final idx = value.toInt();
                              return Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: AppText(
                                  _label(idx),
                                  style: const TextStyle(
                                    fontSize: 10,
                                    color: AppColors.muted,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          curveSmoothness: 0.3,
                          color: AppColors.emerald,
                          barWidth: 2.5,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            gradient: LinearGradient(
                              colors: [
                                AppColors.emerald.withValues(alpha: .25),
                                AppColors.emerald.withValues(alpha: .02),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          getTooltipColor: (spot) => Colors.black87,
                          getTooltipItems: (touched) => touched
                              .map(
                                (spot) => LineTooltipItem(
                                  '${spot.y.toStringAsFixed(0)} ل.س',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: active ? AppColors.emerald : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: AppText(
          label,
          style: TextStyle(
            fontSize: 12,
            color: active ? Colors.white : AppColors.muted,
            fontWeight: active ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }
}

/// بطاقة إجمالي الزيارات + تقييم البائع (نجوم).
class SellerStatsRow extends StatelessWidget {
  final int totalViews;
  final double? sellerRating;
  final int sellerReviewsCount;
  const SellerStatsRow({
    super.key,
    required this.totalViews,
    this.sellerRating,
    required this.sellerReviewsCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _StatBox(
            icon: Icons.remove_red_eye_outlined,
            label: 'إجمالي الزيارات',
            value: '$totalViews',
            color: Colors.blue.shade700,
            bgColor: context.softTint(Colors.blue),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatBox(
            icon: Icons.star_rounded,
            label: 'تقييم متجرك',
            value: sellerRating != null
                ? '${sellerRating!.toStringAsFixed(1)} ★ ($sellerReviewsCount)'
                : 'لا تقييمات بعد',
            color: AppColors.gold,
            bgColor: context.softTint(Colors.amber),
          ),
        ),
      ],
    );
  }
}

class _StatBox extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final Color bgColor;
  const _StatBox({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.bgColor,
  });
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  label,
                  style: const TextStyle(color: AppColors.muted, fontSize: 11),
                ),
                const SizedBox(height: 2),
                AppText(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// شريط تنبيه انخفاض المخزون — يظهر فقط عند وجود منتجات قليلة الكمية.
class LowStockAlertCard extends StatelessWidget {
  final List<Map<String, dynamic>> products;
  final VoidCallback onManage;
  const LowStockAlertCard({
    super.key,
    required this.products,
    required this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    if (products.isEmpty) return const SizedBox.shrink();
    return InkWell(
      onTap: onManage,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.softTint(Colors.red),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.red.shade200),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: context.softTint(Colors.red),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                color: Colors.red.shade700,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    '${products.length} منتج مخزونه منخفض',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Colors.red.shade700,
                    ),
                  ),
                  AppText(
                    products
                        .take(2)
                        .map((p) => '${p['name']} (${p['stock_quantity']})')
                        .join('، '),
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 11,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_left, color: AppColors.muted),
          ],
        ),
      ),
    );
  }
}
