import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../l10n/app_localizations.dart';

class AttributionMetricsCard extends StatelessWidget {
  final int totalVisits;
  final int convertingVisits;
  final int attributedOrders;
  final double conversionRate;

  const AttributionMetricsCard({
    super.key,
    required this.totalVisits,
    required this.convertingVisits,
    required this.attributedOrders,
    required this.conversionRate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AppText('تحويلات المتجر',
              style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          AppText(
              '$convertingVisits من $totalVisits زيارة نتج عنها طلب · $attributedOrders طلب منسوب'),
          AppText('${conversionRate.toStringAsFixed(2)}% معدل التحويل'),
          const SizedBox(height: 4),
          const AppText(
            'المعدل = الزيارات الفريدة المرتبطة بطلب غير ملغى ÷ جميع الزيارات الفريدة. الطلبات غير المرتبطة بزيارة المتجر لا تُحتسب.',
            style: TextStyle(
                color: AppColors.muted, fontSize: 11, height: 1.4),
          ),
        ],
      ),
    );
  }
}
