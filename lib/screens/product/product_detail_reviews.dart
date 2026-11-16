part of 'product_detail_screen.dart';

// قسم التقييمات وزر الضغط المتحرك — منقولان من product_detail_screen.dart كما هما.

class ScaleTapContainer extends StatefulWidget {
  final Widget child;
  final VoidCallback onTap;

  const ScaleTapContainer(
      {super.key, required this.child, required this.onTap});

  @override
  State<ScaleTapContainer> createState() => _ScaleTapContainerState();
}

class _ScaleTapContainerState extends State<ScaleTapContainer> {
  double _scale = 1.0;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _scale = 0.97),
      onTapUp: (_) {
        setState(() => _scale = 1.0);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _scale = 1.0),
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class ProductReviewsSection extends StatefulWidget {
  final double? averageRating;
  final int reviewsCount;
  final List<ProductReview> reviews;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasNextPage;
  final String? error;
  final VoidCallback? onRetry;
  final VoidCallback? onLoadMore;
  final Future<void> Function(int rating, String comment)? onAddReview;

  const ProductReviewsSection({
    super.key,
    this.averageRating,
    required this.reviewsCount,
    required this.reviews,
    required this.isLoading,
    required this.isLoadingMore,
    required this.hasNextPage,
    this.error,
    this.onRetry,
    this.onLoadMore,
    this.onAddReview,
  });

  @override
  State<ProductReviewsSection> createState() => _ProductReviewsSectionState();
}

class _ProductReviewsSectionState extends State<ProductReviewsSection> {
  void _showAddReviewDialog() {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: const AppText('أضف تقييمك للمنتج',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('التقييم بالنجوم:',
                  style: TextStyle(fontSize: 13, color: AppColors.muted)),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 0,
                  runSpacing: 0,
                  children: List.generate(5, (index) {
                    final starVal = index + 1;
                    return IconButton(
                      tooltip: context.tr('تقييم $starVal من 5'),
                      constraints: const BoxConstraints.tightFor(
                        width: 42,
                        height: 42,
                      ),
                      padding: EdgeInsets.zero,
                      icon: Icon(
                        starVal <= rating ? Icons.star : Icons.star_border,
                        color: AppColors.ratingStar,
                        size: 30,
                      ),
                      onPressed: () => setDialogState(() => rating = starVal),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: commentController,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: context.tr('اكتب تعليقك حول المنتج...'),
                  hintStyle:
                      const TextStyle(fontSize: 13, color: AppColors.muted),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.end,
          actionsOverflowAlignment: OverflowBarAlignment.end,
          actionsOverflowButtonSpacing: 8,
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(context),
              child: const AppText('إلغاء',
                  style: TextStyle(color: AppColors.muted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              ),
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (widget.onAddReview == null) return;
                      setDialogState(() => isSubmitting = true);
                      try {
                        await widget.onAddReview!(
                            rating, commentController.text.trim());
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: AppText('تعذّر إرسال التقييم: $e')),
                          );
                        }
                      } finally {
                        if (context.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : const AppText('إرسال التقييم'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasSummary = widget.averageRating != null && widget.reviewsCount > 0;
    final hasReviews = widget.reviews.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.star_rounded,
                      color: AppColors.ratingStar, size: 18),
                  SizedBox(width: 6),
                  AppText(
                    'التقييمات',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ],
              ),
              if (hasSummary)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AppText(
                      widget.averageRating!.toStringAsFixed(1),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.gold : AppColors.primary,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(width: 6),
                    AppText(
                      '${widget.reviewsCount} تقييم',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 12,
                      ),
                    ),
                  ],
                )
              else if (widget.reviewsCount == 0)
                AppText(
                  'لا توجد تقييمات حتى الآن',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                )
              else
                AppText(
                  'التقييمات غير متاحة حالياً',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 12),
                ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    isDark ? const Color(0xFF8CCFB4) : AppColors.primary,
                side: BorderSide(
                    color:
                        isDark ? const Color(0xFF8CCFB4) : AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: _showAddReviewDialog,
              icon: const Icon(Icons.rate_review_outlined, size: 18),
              label: const AppText('أضف تقييمك للمنتج',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 12),
          if (widget.isLoading && !hasReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.primary,
                    ),
                  ),
                  SizedBox(width: 10),
                  AppText(
                    'جاري تحميل التقييمات...',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                ],
              ),
            )
          else if (widget.error != null && !hasReviews)
            AppStateMessage(
              message: widget.error!,
              icon: Icons.error_outline_rounded,
              onRetry: widget.onRetry,
            )
          else if (!widget.isLoading && !hasReviews)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 10),
              child: AppStateMessage(
                message: 'لا توجد تقييمات حتى الآن. كن أول من يتقيّم!',
                icon: Icons.star_border_rounded,
              ),
            )
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: widget.reviews.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final review = widget.reviews[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: context.mutedSurface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.softBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AppText(
                              review.customerName.isNotEmpty
                                  ? review.customerName
                                  : 'زبون',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          if (review.verifiedPurchase)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: const Color(0xFFEAF7EF),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: const AppText(
                                'شراء موثّق',
                                style: TextStyle(
                                  color: Color(0xFF1E7F46),
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          ...List.generate(5, (starIndex) {
                            final filled = starIndex < review.rating;
                            return Icon(
                              filled
                                  ? Icons.star_rounded
                                  : Icons.star_border_rounded,
                              size: 16,
                              color: AppColors.ratingStar,
                            );
                          }),
                          const SizedBox(width: 8),
                          if (review.createdAt != null)
                            AppText(
                              DateFormat('d MMM y', 'ar')
                                  .format(review.createdAt!),
                              style: const TextStyle(
                                color: AppColors.muted,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                      if (review.comment != null &&
                          review.comment!.trim().isNotEmpty) ...[
                        const SizedBox(height: 8),
                        AppText(
                          review.comment!.trim(),
                          style: const TextStyle(
                            color: AppColors.muted,
                            fontSize: 12,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
            if (widget.hasNextPage) ...[
              const SizedBox(height: 12),
              Center(
                child: SizedBox(
                  width: 180,
                  child: TextButton.icon(
                    onPressed: widget.isLoadingMore || widget.onLoadMore == null
                        ? null
                        : widget.onLoadMore,
                    icon: widget.isLoadingMore
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.primary,
                            ),
                          )
                        : const Icon(Icons.expand_more_rounded, size: 16),
                    label: AppText(
                      widget.isLoadingMore ? 'جاري التحميل...' : 'عرض المزيد',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}
