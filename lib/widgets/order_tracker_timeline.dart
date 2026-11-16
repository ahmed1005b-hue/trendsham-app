import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import '../config/theme.dart';

class OrderTrackerTimeline extends StatelessWidget {
  final String status;
  final String? trackingNumber;
  final String? shippingCompany;

  const OrderTrackerTimeline({
    super.key,
    required this.status,
    this.trackingNumber,
    this.shippingCompany,
  });

  @override
  Widget build(BuildContext context) {
    if (status == 'cancelled') {
      return _buildCancelledState();
    }

    // مراحل الطلب الأساسية اللي بتتبعها الشحنة
    final steps = ['pending', 'processing', 'shipped', 'delivered'];

    // نتعامل مع "مدفوع" في نفس مكان "قيد المراجعة" من ناحية التتبع
    final normalizedStatus = status == 'paid' ? 'pending' : status;
    int currentIndex = steps.indexOf(normalizedStatus);
    if (currentIndex == -1) currentIndex = 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const AppText(
          'تتبع حالة الطلب',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 20),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStep('المراجعة', Icons.assignment_outlined, currentIndex >= 0,
                currentIndex == 0),
            _buildLine(currentIndex >= 1),
            _buildStep('التجهيز', Icons.inventory_2_outlined, currentIndex >= 1,
                currentIndex == 1),
            _buildLine(currentIndex >= 2),
            _buildStep('تم الشحن', Icons.local_shipping_outlined,
                currentIndex >= 2, currentIndex == 2),
            _buildLine(currentIndex >= 3),
            _buildStep('تم التسليم', Icons.check_circle_outline,
                currentIndex >= 3, currentIndex == 3),
          ],
        ),
        if (trackingNumber != null && currentIndex >= 2) ...[
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.qr_code_scanner, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const AppText(
                        'رقم توليد الشحن:',
                        style: TextStyle(fontSize: 12, color: AppColors.muted),
                      ),
                      const SizedBox(height: 4),
                      AppText(
                        trackingNumber!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
        if (shippingCompany != null && currentIndex >= 2) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              const Icon(Icons.local_shipping_outlined,
                  size: 18, color: AppColors.muted),
              const SizedBox(width: 8),
              AppText(
                'شركة الشحن: $shippingCompany',
                style: const TextStyle(fontSize: 13, color: AppColors.muted),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildStep(
      String label, IconData icon, bool reached, bool isCurrent) {
    final color = reached ? AppColors.primary : AppColors.muted;
    return Expanded(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: reached
                  ? AppColors.primary.withValues(alpha: 0.12)
                  : AppColors.muted.withValues(alpha: 0.08),
              border: Border.all(
                color: isCurrent ? AppColors.primary : color.withValues(alpha: 0.3),
                width: isCurrent ? 2 : 1,
              ),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          AppText(
            label,
            style: TextStyle(
              fontSize: 11,
              color: reached ? AppColors.darkInk : AppColors.muted,
              fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildLine(bool reached) {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      width: 24,
      height: 2,
      color: reached ? AppColors.primary : AppColors.muted.withValues(alpha: 0.3),
    );
  }

  Widget _buildCancelledState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.2)),
      ),
      child: const Row(
        children: [
          Icon(Icons.cancel_outlined, color: AppColors.danger),
          SizedBox(width: 12),
          Expanded(
            child: AppText(
              'تم إلغاء هذا الطلب',
              style: TextStyle(
                color: AppColors.danger,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
