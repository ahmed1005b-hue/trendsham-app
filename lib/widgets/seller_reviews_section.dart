import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/seller_review.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// قسم تقييمات البائع — نجوم للمتجر نفسه (وليس المنتجات فقط)
/// يُستخدم داخل صفحة المتجر (StoreScreen).
class SellerReviewsSection extends StatefulWidget {
  final int storeId;
  const SellerReviewsSection({super.key, required this.storeId});

  @override
  State<SellerReviewsSection> createState() => _SellerReviewsSectionState();
}

class _SellerReviewsSectionState extends State<SellerReviewsSection> {
  final SellerService _service = SellerService();
  StoreReviewsPage? _page;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final page = await _service.storeReviews(widget.storeId);
      setState(() => _page = page);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل التقييمات.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.emerald,
          ),
        ),
      );
    }
    if (_error != null) {
      return AppStateMessage(
        message: _error!,
        icon: Icons.error_outline,
        onRetry: _load,
      );
    }
    final page = _page;
    if (page == null || page.reviews.isEmpty) {
      return const SizedBox.shrink(); // لا تقييمات بعد — نخفي القسم
    }

    final avg = page.averageRating;
    final breakdown = page.ratingBreakdown; // {'5': n, '4': n, ...}
    final total = page.reviewsCount;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.softBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.storefront, color: AppColors.emerald, size: 20),
              SizedBox(width: 6),
              AppText(
                'تقييمات المتجر',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ملخص النجوم
          Row(
            children: [
              AppText(
                avg != null ? avg.toStringAsFixed(1) : '-',
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkInk,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: List.generate(5, (i) {
                      final filled = avg != null && i < avg.round();
                      return Icon(
                        filled ? Icons.star : Icons.star_border,
                        size: 18,
                        color: AppColors.gold,
                      );
                    }),
                  ),
                  AppText(
                    '$total تقييم',
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 10),
          // توزيع النجوم (5..1)
          ...List.generate(5, (i) {
            final stars = 5 - i; // 5,4,3,2,1
            final count = (breakdown['$stars'] as num?)?.toInt() ?? 0;
            final pct = total > 0 ? count / total : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 12,
                    child: AppText(
                      '$stars',
                      style: const TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                  ),
                  const Icon(Icons.star, size: 12, color: AppColors.gold),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: pct,
                        minHeight: 6,
                        backgroundColor: AppColors.bgLight,
                        valueColor: const AlwaysStoppedAnimation(
                          AppColors.gold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  SizedBox(
                    width: 28,
                    child: AppText(
                      '$count',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                      textAlign: TextAlign.end,
                    ),
                  ),
                ],
              ),
            );
          }),
          const Divider(height: 24),
          // أحدث 3 تقييمات مع تعليقات
          ...page.reviews
              .take(3)
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Row(
                            children: List.generate(
                              5,
                              (i) => Icon(
                                i < r.rating ? Icons.star : Icons.star_border,
                                size: 14,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                          const Spacer(),
                          AppText(
                            r.userName ?? 'عميل',
                            style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.muted,
                            ),
                          ),
                        ],
                      ),
                      if (r.comment != null && r.comment!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        AppText(
                          r.comment!,
                          style: const TextStyle(fontSize: 12, height: 1.4),
                        ),
                      ],
                      if (r.productName != null) ...[
                        const SizedBox(height: 2),
                        AppText(
                          'على منتج: ${r.productName}',
                          style: const TextStyle(
                            fontSize: 11,
                            color: AppColors.muted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }
}
