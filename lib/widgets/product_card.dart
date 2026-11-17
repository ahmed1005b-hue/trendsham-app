import 'dart:async';

import 'package:animations/animations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../config/theme.dart';
import '../models/product.dart';
import '../l10n/app_localizations.dart';

class ProductCard extends StatefulWidget {
  final Product product;
  final VoidCallback onTap;
  final VoidCallback? onFavoriteTap;
  final bool? isFavorited;
  final VoidCallback? onImageTap;
  final VoidCallback? onImageLongPress;
  final VoidCallback? onCompareTap;
  final VoidCallback? onQuestionsTap;
  final void Function(BuildContext sourceContext, String? imageUrl,
      {double? specialPrice, int? discountPercentage})? onAddToCart;
  final bool autoPlayImages;
  final WidgetBuilder? openBuilder;

  const ProductCard({
    super.key,
    required this.product,
    required this.onTap,
    this.onFavoriteTap,
    this.isFavorited,
    this.onImageTap,
    this.onImageLongPress,
    this.onCompareTap,
    this.onQuestionsTap,
    this.onAddToCart,
    this.autoPlayImages = true,
    this.openBuilder,
  });

  @override
  State<ProductCard> createState() => _ProductCardState();
}

class _ProductCardState extends State<ProductCard> {
  late final PageController _pageController;
  Timer? _autoPlayTimer;
  int _currentIndex = 0;
  bool _userInteracting = false;

  /// صور البطاقة بالنسخة الصغيرة (أخف تحميلاً وبنفس الوضوح على البطاقة)
  List<String> get _imageUrls {
    final list = <String>[];
    final seen = <String>{};
    final primary = widget.product.primaryImage;
    if (primary != null && primary.url.isNotEmpty && seen.add(primary.url)) {
      list.add(primary.listUrl);
    }
    for (final img in widget.product.images) {
      if (img.url.isNotEmpty && seen.add(img.url)) list.add(img.listUrl);
    }
    if (list.isEmpty) return const [];
    return list.take(5).toList();
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _startAutoPlay();
    });
  }

  @override
  void didUpdateWidget(ProductCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.product.id != widget.product.id ||
        oldWidget.product.images.length != widget.product.images.length ||
        oldWidget.product.primaryImage?.url !=
            widget.product.primaryImage?.url) {
      _currentIndex = 0;
      if (_pageController.hasClients) _pageController.jumpToPage(0);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startAutoPlay();
      });
    }
  }

  void _startAutoPlay(
      {Duration initialDelay = const Duration(milliseconds: 2200)}) {
    _autoPlayTimer?.cancel();
    if (!mounted || !widget.autoPlayImages || _userInteracting) return;
    final disable = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (disable) return;
    if (_imageUrls.length <= 1) return;
    _autoPlayTimer = Timer(initialDelay, _tickAutoPlay);
  }

  void _tickAutoPlay() {
    _autoPlayTimer?.cancel();
    if (!mounted || !widget.autoPlayImages || _userInteracting) return;
    if (MediaQuery.maybeOf(context)?.disableAnimations ?? false) return;
    final count = _imageUrls.length;
    if (count <= 1 || !_pageController.hasClients) return;
    final nextIndex = (_currentIndex + 1) % count;
    _pageController.animateToPage(
      nextIndex,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeInOut,
    );
    _autoPlayTimer = Timer(const Duration(milliseconds: 2200), _tickAutoPlay);
  }

  void _goTo(int index) {
    final count = _imageUrls.length;
    if (count <= 1 || !_pageController.hasClients) return;
    final next = (index % count + count) % count;
    _userInteracting = true;
    _autoPlayTimer?.cancel();
    _pageController
        .animateToPage(next,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeInOut)
        .whenComplete(() {
      if (!mounted) return;
      _userInteracting = false;
      _startAutoPlay(initialDelay: const Duration(milliseconds: 3200));
    });
  }

  @override
  void dispose() {
    _autoPlayTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final priceColor = isDark ? AppColors.gold : AppColors.brandGreen;
    final urls = _imageUrls;
    final deal = widget.product.hasActiveDeal;
    final discount = widget.product.displayDiscountPercentage;

    if (widget.openBuilder != null) {
      return OpenContainer(
        closedBuilder: (context, openContainer) {
          return InkWell(
            onTap: openContainer,
            borderRadius: BorderRadius.circular(12),
            child: _buildCardContent(
              context,
              effectiveOnTap: openContainer,
              colorScheme: colorScheme,
              priceColor: priceColor,
              urls: urls,
              deal: deal,
              discount: discount,
            ),
          );
        },
        openBuilder: (context, closeContainer) => widget.openBuilder!(context),
        closedColor: Theme.of(context).colorScheme.surface,
        openColor: Theme.of(context).scaffoldBackgroundColor,
        closedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        transitionDuration: const Duration(milliseconds: 380),
        tappable: false,
      );
    }

    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(12),
      child: _buildCardContent(
        context,
        effectiveOnTap: widget.onTap,
        colorScheme: colorScheme,
        priceColor: priceColor,
        urls: urls,
        deal: deal,
        discount: discount,
      ),
    );
  }

  Widget _buildCardContent(
    BuildContext context, {
    required VoidCallback effectiveOnTap,
    required ColorScheme colorScheme,
    required Color priceColor,
    required List<String> urls,
    required bool deal,
    required int? discount,
  }) {
    final safeIndex =
        urls.isEmpty ? 0 : _currentIndex.clamp(0, urls.length - 1);
    return MouseRegion(
      onEnter: (_) {
        _userInteracting = true;
        _autoPlayTimer?.cancel();
      },
      onExit: (_) {
        _userInteracting = false;
        _startAutoPlay();
      },
      child: Container(
        key: const ValueKey('product-card-shell'),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant, width: 0.8),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2))
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalHeight =
                constraints.maxHeight.isFinite && constraints.maxHeight > 0
                    ? constraints.maxHeight
                    : 280.0;
            final imageHeight = totalHeight * 0.58;
            final detailsHeight = totalHeight - imageHeight;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  height: imageHeight,
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: ColoredBox(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? Colors.transparent
                              : Colors.white,
                          child: urls.length <= 1
                              ? GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: widget.onImageTap ?? effectiveOnTap,
                                  onLongPress: widget.onImageLongPress,
                                  child: Padding(
                                    padding: const EdgeInsets.all(8),
                                    child: urls.isEmpty
                                        ? _placeholder(context)
                                        : CachedNetworkImage(
                                            imageUrl: urls.first,
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            filterQuality: FilterQuality.high,
                                            errorWidget: (_, __, ___) =>
                                                _placeholder(context),
                                            placeholder: (_, __) =>
                                                _placeholder(context),
                                          ),
                                  ),
                                )
                              : Listener(
                                  onPointerDown: (_) {
                                    _userInteracting = true;
                                    _autoPlayTimer?.cancel();
                                  },
                                  onPointerUp: (_) {
                                    _userInteracting = false;
                                    _startAutoPlay(
                                        initialDelay:
                                            const Duration(milliseconds: 3200));
                                  },
                                  onPointerCancel: (_) {
                                    _userInteracting = false;
                                    _startAutoPlay(
                                        initialDelay:
                                            const Duration(milliseconds: 3200));
                                  },
                                  child: PageView.builder(
                                    controller: _pageController,
                                    physics: const PageScrollPhysics(
                                        parent: BouncingScrollPhysics()),
                                    itemCount: urls.length,
                                    onPageChanged: (i) {
                                      setState(() => _currentIndex = i);
                                    },
                                    itemBuilder: (context, index) {
                                      return GestureDetector(
                                        behavior: HitTestBehavior.translucent,
                                        onTap:
                                            widget.onImageTap ?? effectiveOnTap,
                                        onLongPress: widget.onImageLongPress,
                                        child: Padding(
                                          padding: const EdgeInsets.all(8),
                                          child: CachedNetworkImage(
                                            imageUrl: urls[index],
                                            fit: BoxFit.contain,
                                            alignment: Alignment.center,
                                            filterQuality: FilterQuality.high,
                                            errorWidget: (_, __, ___) =>
                                                _placeholder(context),
                                            placeholder: (_, __) =>
                                                _placeholder(context),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ),
                      if (urls.length > 1) ...[
                        PositionedDirectional(
                            start: 2,
                            top: 0,
                            bottom: 18,
                            child: Center(
                                child: _navButton(
                                    Icons.chevron_left_rounded,
                                    () => _goTo(safeIndex - 1),
                                    'الصورة السابقة'))),
                        PositionedDirectional(
                            end: 2,
                            top: 0,
                            bottom: 18,
                            child: Center(
                                child: _navButton(
                                    Icons.chevron_right_rounded,
                                    () => _goTo(safeIndex + 1),
                                    'الصورة التالية'))),
                        Positioned(
                          bottom: 6,
                          left: 0,
                          right: 0,
                          child: Center(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 7, vertical: 3),
                              decoration: BoxDecoration(
                                  color: Colors.black.withValues(alpha: 0.38),
                                  borderRadius: BorderRadius.circular(10)),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: List.generate(urls.length, (index) {
                                  final active = safeIndex == index;
                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 220),
                                    width: active ? 9 : 4,
                                    height: 4,
                                    margin: const EdgeInsets.symmetric(
                                        horizontal: 1.5),
                                    decoration: BoxDecoration(
                                        color: active
                                            ? Colors.white
                                            : Colors.white70,
                                        borderRadius: BorderRadius.circular(2)),
                                  );
                                }),
                              ),
                            ),
                          ),
                        ),
                      ],
                      Positioned(
                        top: 8,
                        left: 8,
                        child: GestureDetector(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            widget.onFavoriteTap?.call();
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                      color:
                                          Colors.black.withValues(alpha: 0.12),
                                      blurRadius: 4,
                                      offset: const Offset(0, 2))
                                ]),
                            child: Icon(
                                (widget.isFavorited ??
                                        widget.product.isFavorited)
                                    ? Icons.favorite
                                    : Icons.favorite_border,
                                color: (widget.isFavorited ??
                                        widget.product.isFavorited)
                                    ? AppColors.danger
                                    : Colors.grey.shade700,
                                size: 18),
                          ),
                        ),
                      ),
                      if (deal)
                        Positioned(
                          top: 8,
                          right: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 4),
                            decoration: BoxDecoration(
                                color: AppColors.sale,
                                borderRadius: BorderRadius.circular(8)),
                            child: AppText(
                                widget.product.dealLabel ?? 'عرض اليوم',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    height: 1)),
                          ),
                        ),
                      if (widget.onCompareTap != null)
                        Positioned(
                            top: deal ? 38 : 8,
                            right: 8,
                            child: _toolButton(Icons.compare_arrows,
                                widget.onCompareTap!, 'إضافة للمقارنة')),
                      if (widget.onQuestionsTap != null)
                        Positioned(
                            bottom: urls.length > 1 ? 24 : 8,
                            left: 6,
                            child: _toolButton(Icons.help_outline,
                                widget.onQuestionsTap!, 'أسئلة وأجوبة المنتج')),
                      if (widget.onAddToCart != null)
                        Positioned(
                          bottom: urls.length > 1 ? 24 : 8,
                          right: 6,
                          child: Builder(
                            builder: (btnContext) => Material(
                              color: AppColors.brandGreen,
                              shape: const CircleBorder(),
                              elevation: 2,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  HapticFeedback.mediumImpact();
                                  widget.onAddToCart!(
                                      btnContext,
                                      urls.isNotEmpty
                                          ? urls[safeIndex]
                                          : widget.product.primaryImage?.url,
                                      specialPrice:
                                          widget.product.displayPrice <
                                                  widget.product.price
                                              ? widget.product.displayPrice
                                              : null,
                                      discountPercentage: widget
                                          .product.displayDiscountPercentage);
                                },
                                child: const SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: Icon(Icons.add_shopping_cart_rounded,
                                        size: 16, color: Colors.white)),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                SizedBox(
                  height: detailsHeight,
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    child: SingleChildScrollView(
                      physics: const NeverScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          AppText(
                            widget.product.vendor?.storeName ??
                                (widget.product.category?.localizedName(
                                        Localizations.localeOf(context)
                                            .languageCode) ??
                                    widget.product.category?.name) ??
                                'تريند شام',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w900,
                              color: Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? AppColors.gold
                                  : AppColors.brandGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppText(widget.product.name,
                              key: const ValueKey('product-card-name'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  fontSize: 11,
                                  height: 1.15,
                                  color: colorScheme.onSurfaceVariant)),
                          const SizedBox(height: 4),
                          Row(children: [
                            const Icon(Icons.star_rounded,
                                color: AppColors.gold, size: 11),
                            const SizedBox(width: 2),
                            AppText(
                                widget.product.averageRating != null
                                    ? widget.product.averageRating!
                                        .toStringAsFixed(1)
                                    : '—',
                                style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                    color: colorScheme.onSurface)),
                            const SizedBox(width: 3),
                            AppText('(${widget.product.reviewsCount})',
                                key:
                                    const ValueKey('product-card-review-count'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant)),
                          ]),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Flexible(
                                  child: AppText(widget.product.formattedPrice,
                                      key: const ValueKey('product-card-price'),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w900,
                                          color: Theme.of(context).brightness ==
                                                  Brightness.dark
                                              ? AppColors.gold
                                              : AppColors.brandGreen))),
                              if (discount != null && discount > 0) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 4, vertical: 2),
                                  decoration: BoxDecoration(
                                      color: AppColors.sale,
                                      borderRadius: BorderRadius.circular(4)),
                                  child: AppText('-%$discount',
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold)),
                                ),
                              ],
                            ],
                          ),
                          if (widget.product.formattedCompareAtPrice !=
                              null) ...[
                            const SizedBox(height: 1),
                            AppText(widget.product.formattedCompareAtPrice!,
                                key: const ValueKey(
                                    'product-card-compare-price'),
                                style: TextStyle(
                                    fontSize: 11,
                                    color: colorScheme.onSurfaceVariant,
                                    decoration: TextDecoration.lineThrough)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _navButton(IconData icon, VoidCallback onTap, String label) {
    return Tooltip(
      message: label,
      child: Material(
          color: Colors.white.withValues(alpha: 0.92),
          shape: const CircleBorder(),
          child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: SizedBox(
                  width: 28,
                  height: 28,
                  child: Icon(icon, size: 18, color: Colors.grey.shade800)))),
    );
  }

  Widget _toolButton(IconData icon, VoidCallback onTap, String tooltip) {
    return IconButton(
        tooltip: tooltip,
        onPressed: onTap,
        style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            minimumSize: const Size(26, 26),
            padding: EdgeInsets.zero),
        icon: Icon(icon, size: 15));
  }

  Widget _placeholder(BuildContext context) {
    return ColoredBox(
        key: const ValueKey('product-image-placeholder'),
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Center(
            child: Icon(Icons.image_not_supported_outlined,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: 28)));
  }
}
