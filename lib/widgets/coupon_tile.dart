import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/wallet_coupon.dart';
import '../l10n/app_localizations.dart';

/// بطاقة كوبون: شريط القيمة الملوّن (زمردي للمنصة، ذهبي للمتجر) ثم التفاصيل.
class CouponTile extends StatelessWidget {
  final WalletCoupon coupon;
  final bool muted;
  final String? note;
  final Widget? trailing;
  final VoidCallback? onTap;

  const CouponTile({
    super.key,
    required this.coupon,
    this.muted = false,
    this.note,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final accent = coupon.isSeller ? AppColors.gold : AppColors.emerald;
    final exp = coupon.expiresAt;
    return Opacity(
      opacity: muted ? 0.6 : 1,
      child: Material(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(14),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 96,
                    color: accent,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          coupon.isFreeShipping
                              ? Icons.local_shipping_outlined
                              : Icons.confirmation_number_outlined,
                          color: Colors.white,
                        ),
                        const SizedBox(height: 4),
                        AppText(
                          coupon.valueLabel,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AppText(coupon.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style:
                                  const TextStyle(fontWeight: FontWeight.bold)),
                          if (coupon.sourceLabel != null)
                            AppText(coupon.sourceLabel!,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          if (coupon.minOrderAmount > 0)
                            AppText(
                                'للطلبات من ${coupon.minOrderAmount.toStringAsFixed(0)} ل.س',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.muted)),
                          if (note != null)
                            AppText(note!,
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: muted
                                        ? AppColors.danger
                                        : AppColors.emerald))
                          else if (exp != null && coupon.status == 'available')
                            AppText(
                              coupon.expiresSoon
                                  ? 'ينتهي قريباً: ${_date(exp)}'
                                  : 'ينتهي في ${_date(exp)}',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: coupon.expiresSoon
                                      ? AppColors.danger
                                      : AppColors.muted),
                            ),
                        ],
                      ),
                    ),
                  ),
                  if (trailing != null)
                    Padding(
                        padding: const EdgeInsetsDirectional.only(end: 8),
                        child: Center(child: trailing)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
