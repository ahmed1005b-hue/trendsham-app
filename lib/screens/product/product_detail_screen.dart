import '../../services/loyalty_service.dart';
import '../../widgets/store_coupons_strip.dart';
import 'dart:ui';
import '../../models/product_options.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/product_review.dart';
import '../../services/product_service.dart';
import '../../services/recently_viewed_store.dart';
import '../../services/api_exception.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/product_card.dart';
import '../../widgets/product_questions_section.dart';
import '../cart/cart_screen.dart';
import '../../utils/auth_prompt.dart';
import '../../widgets/fly_to_cart.dart';
import '../store/store_screen.dart';
import '../../widgets/shimmer_loading.dart';

part 'product_detail_reviews.dart';

class ProductDetailScreen extends StatefulWidget {
  final String slug;
  final Product? initialProduct;
  final bool openQuestions;

  const ProductDetailScreen({
    super.key,
    required this.slug,
    this.initialProduct,
    this.openQuestions = false,
  });

  @override
  State<ProductDetailScreen> createState() => _ProductDetailScreenState();
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  final ProductService _productService = ProductService();
  final FavoriteService _favoriteService = FavoriteService();
  final PageController _imagePageController = PageController();
  final GlobalKey _questionsAnchor = GlobalKey();
  final GlobalKey _addToCartButtonKey =
      GlobalKey(debugLabel: "product-add-to-cart");
  final GlobalKey _cartIconKey =
      GlobalKey(debugLabel: "product-detail-cart-icon");
  Product? _product;
  List<Product> _similarProducts = [];
  List<Product> _popularProducts = [];
  List<ProductReview> _reviews = [];
  String? _recommendationsError;
  String? _reviewsError;
  String? _error;
  bool _isAddingToCart = false;
  bool _isLoadingReviews = false;
  bool _isLoadingMoreReviews = false;
  int _reviewsPage = 0;
  int _reviewsLastPage = 1;
  int _activeImageIndex = 0;
  int _selectedQuantity = 1;
  int? _selectedVariantId;
  String? _selectedColor;
  String? _selectedSize;

  List<ProductVariant> get _variants => _product?.variants ?? const [];
  bool get _hasVariants => _variants.isNotEmpty;
  List<ProductVariant> get _availableColors =>
      _variants.where((v) => (v.color ?? '').isNotEmpty).toList();
  List<String> get _colorKeys =>
      _availableColors.map((v) => v.color!).toSet().toList();
  List<String> get _sizeKeys => _variants
      .map((v) => v.size ?? '')
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  ProductVariant? get _selectedVariant {
    if (!_hasVariants) return null;
    if (_selectedVariantId != null) {
      for (final v in _variants) {
        if (v.id == _selectedVariantId) return v;
      }
    }
    for (final v in _variants) {
      if ((_selectedColor == null || v.color == _selectedColor) &&
          (_selectedSize == null || v.size == _selectedSize)) {
        return v;
      }
    }
    return _variants.first;
  }

  bool get _isOutOfStock => _hasVariants
      ? ((_selectedVariant?.stockQuantity ?? 0) <= 0)
      : !(_product?.inStock ?? false);
  double get _effectiveUnitPrice {
    final p = _product;
    if (p == null) return 0;
    final base = p.displayPrice;
    return base + (_selectedVariant?.priceAdjustment ?? 0);
  }

  String get _formattedTotalPrice {
    final total = _effectiveUnitPrice * _selectedQuantity;
    return '${total.toStringAsFixed(0)} ل.س';
  }

  @override
  void initState() {
    super.initState();
    _product = widget.initialProduct;
    _load();
  }

  @override
  void dispose() {
    _imagePageController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final product = await _productService.show(widget.slug);
      RecentlyViewedStore.add(product.id);
      if (!mounted) return;
      setState(() {
        _product = product;
        _initVariantSelection(product);
      });
      if (widget.openQuestions) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final anchorContext = _questionsAnchor.currentContext;
          if (mounted && anchorContext != null) {
            Scrollable.ensureVisible(
              anchorContext,
              duration: const Duration(milliseconds: 350),
              alignment: 0.1,
            );
          }
        });
      }
      await _loadReviews(reset: true);

      try {
        final recommendations =
            await _productService.recommendations(widget.slug);
        if (!mounted) return;
        setState(() {
          _similarProducts = recommendations.similar;
          _popularProducts = recommendations.popular;
          _recommendationsError = null;
        });
      } on ApiException catch (e) {
        if (mounted) setState(() => _recommendationsError = e.message);
      } catch (e) {
        if (mounted) {
          setState(() =>
              _recommendationsError = 'تعذّر تحميل اقتراحات المنتجات: $e');
        }
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل المنتج.');
    }
  }

  void _initVariantSelection(Product product) {
    final vs = product.variants;
    if (vs.isEmpty) return;
    final first =
        vs.firstWhere((v) => v.stockQuantity > 0, orElse: () => vs.first);
    _selectedVariantId = first.id;
    _selectedColor = first.color;
    _selectedSize = first.size;
  }

  void _selectColor(String? color) {
    if (color == null) return;
    final candidates = _variants.where((v) => v.color == color).toList();
    final match = candidates.firstWhere(
        (v) => v.size == _selectedSize && v.stockQuantity > 0,
        orElse: () => candidates.firstWhere((v) => v.stockQuantity > 0,
            orElse: () => candidates.first));
    setState(() {
      _selectedColor = color;
      _selectedSize = match.size;
      _selectedVariantId = match.id;
      _selectedQuantity = 1;
    });
    _jumpToColorImage(color);
  }

  void _selectSize(String? size) {
    if (size == null) return;
    ProductVariant? match;
    for (final v in _variants) {
      if (v.size == size &&
          (_selectedColor == null || v.color == _selectedColor)) {
        match = v;
        break;
      }
    }
    match ??= _variants.firstWhere((v) => v.size == size,
        orElse: () => _variants.first);
    setState(() {
      _selectedSize = size;
      _selectedColor = match!.color ?? _selectedColor;
      _selectedVariantId = match.id;
      _selectedQuantity = 1;
    });
  }

  void _jumpToColorImage(String color) {
    final p = _product;
    if (p == null) return;
    final idx = p.images.indexWhere((img) => img.color == color);
    if (idx >= 0 && _imagePageController.hasClients) {
      _imagePageController.jumpToPage(idx);
    }
  }

  Future<void> _loadReviews({bool reset = false}) async {
    if (_isLoadingReviews || _isLoadingMoreReviews) return;
    final page = reset ? 1 : _reviewsPage + 1;
    setState(() {
      _reviewsError = null;
      if (reset) {
        _isLoadingReviews = true;
      } else {
        _isLoadingMoreReviews = true;
      }
    });

    try {
      final result = await _productService.reviews(widget.slug, page: page);
      if (!mounted) return;
      setState(() {
        _reviews = reset ? result.reviews : [..._reviews, ...result.reviews];
        _reviewsPage = result.currentPage;
        _reviewsLastPage = result.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _reviewsError = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _reviewsError = 'تعذّر تحميل التقييمات.');
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoadingReviews = false;
          _isLoadingMoreReviews = false;
        });
      }
    }
  }

  void _openImageViewer(String imageUrl) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 1,
                maxScale: 4,
                child: CachedNetworkImage(
                  imageUrl: imageUrl,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              top: 16,
              right: 12,
              child: IconButton(
                tooltip: context.tr('إغلاق الصورة'),
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addToCart({GlobalKey? sourceKey, int? quantity}) async {
    if (_product == null || _isOutOfStock) return;

    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      final authenticated = await showAuthRequiredDialog(context);
      if (!mounted || !authenticated) return;
    }
    if (context.read<AuthProvider>().user?.role != 'customer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('الشراء متاح لحسابات العملاء فقط.')),
      );
      return;
    }

    final qty = quantity ?? _selectedQuantity;
    setState(() => _isAddingToCart = true);
    try {
      final variant = _selectedVariant;
      await context.read<CartProvider>().add(_product!.id,
          quantity: qty,
          specialPrice:
              _product!.displayPrice + (variant?.priceAdjustment ?? 0),
          discountPercentage: _product!.displayDiscountPercentage,
          variantId: variant?.id);
      if (!mounted) return;
      await FlyToCart.run(
        context,
        targetKey: _cartIconKey,
        sourceKey: sourceKey ?? _addToCartButtonKey,
        imageUrl: _product?.primaryImage?.url ??
            (_product?.images.isNotEmpty == true
                ? _product!.images.first.url
                : null),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: AppText('تمت إضافة المنتج إلى السلة بنجاح!'),
            backgroundColor: AppColors.primary),
      );
    } on ApiException catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(e.message)));
    } finally {
      if (mounted) setState(() => _isAddingToCart = false);
    }
  }

  /// مشاركة المنتج: نص جميل + رابط المنتج عبر أرضية المشاركة (واتساب، تيليغرام...)
  Future<void> _shareProduct() async {
    final product = _product;
    if (product == null) return;
    final l10n = AppLocalizations.of(context);
    final name = product.name;
    final price = product.formattedPrice;
    final url = '${ApiConfig.storageBaseUrl}/product/${product.slug}';
    final text = '$name - $price`n$url';
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, title: name, subject: name),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: AppText(l10n.translate('تعذر المشاركة.'))),
      );
    }
  }

  Future<void> _toggleFavorite() async {
    if (_product == null) return;
    if (!context.read<AuthProvider>().isLoggedIn) {
      final authenticated = await showAuthRequiredDialog(context);
      if (!mounted || !authenticated) return;
    }
    try {
      final favorited = await _favoriteService.toggle(_product!.id);
      setState(() {
        _product = _product!.copyWith(isFavorited: favorited);
      });
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: AppStateMessage(
            message: _error!, icon: Icons.error_outline, onRetry: _load),
      );
    }

    if (_product == null) {
      return Scaffold(appBar: AppBar(), body: const ProductDetailSkeleton());
    }

    final product = _product!;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final List<String> imageUrls = product.images.isNotEmpty
        ? product.images.map((img) => img.url).toList()
        : (product.primaryImage != null ? [product.primaryImage!.url] : []);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: CustomScrollView(
        slivers: [
          // الهيدر وسلايدر صور المنتج
          SliverAppBar(
            expandedHeight: 380,
            pinned: true,
            backgroundColor: Theme.of(context).colorScheme.surface,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            actions: [
              _appBarAction(
                icon: const Icon(Icons.share_outlined),
                iconColor:
                    isDark ? const Color(0xFF8CCFB4) : AppColors.brandGreen,
                onPressed: _shareProduct,
                tooltip: context.tr('مشاركة'),
              ),
              _appBarAction(
                icon: Icon(
                  product.isFavorited ? Icons.favorite : Icons.favorite_border,
                ),
                iconColor: product.isFavorited
                    ? AppColors.danger
                    : (isDark ? const Color(0xFF8CCFB4) : AppColors.brandGreen),
                onPressed: _toggleFavorite,
                tooltip: product.isFavorited
                    ? 'إزالة من المفضلة'
                    : 'إضافة إلى المفضلة',
              ),
              Container(
                key: _cartIconKey,
                margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.9),
                  shape: BoxShape.circle,
                  border: Border.all(
                      color: (isDark
                              ? const Color(0xFF8CCFB4)
                              : AppColors.brandGreen)
                          .withValues(alpha: 0.25)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Consumer<CartProvider>(
                  builder: (context, cart, _) => IconButton(
                    tooltip: context.tr('السلة'),
                    icon: Badge(
                      label: AppText('${cart.itemCount}'),
                      isLabelVisible: cart.itemCount > 0,
                      backgroundColor: AppColors.primary,
                      child: Icon(Icons.shopping_cart_outlined,
                          color: isDark
                              ? const Color(0xFF8CCFB4)
                              : AppColors.brandGreen),
                    ),
                    onPressed: () {
                      if (!context.read<AuthProvider>().isLoggedIn) {
                        showAuthRequiredDialog(context);
                        return;
                      }
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const CartScreen()),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                alignment: Alignment.bottomCenter,
                children: [
                  imageUrls.isNotEmpty
                      ? PageView.builder(
                          controller: _imagePageController,
                          itemCount: imageUrls.length,
                          onPageChanged: (i) =>
                              setState(() => _activeImageIndex = i),
                          itemBuilder: (context, index) {
                            return GestureDetector(
                              onTap: () => _openImageViewer(imageUrls[index]),
                              child: Container(
                                color: Theme.of(context)
                                    .colorScheme
                                    .surfaceContainerHighest
                                    .withValues(alpha: 0.25),
                                child: CachedNetworkImage(
                                  imageUrl: imageUrls[index],
                                  fit: BoxFit.contain,
                                  alignment: Alignment.center,
                                  filterQuality: FilterQuality.high,
                                ),
                              ),
                            );
                          },
                        )
                      : Container(
                          color: context.mutedSurface,
                          child: const Center(
                            child: Icon(Icons.image_not_supported_outlined,
                                size: 64, color: AppColors.muted),
                          ),
                        ),
                  if (imageUrls.length > 1)
                    Positioned(
                      bottom: 12,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          imageUrls.length,
                          (i) => Container(
                            width: _activeImageIndex == i ? 16 : 6,
                            height: 6,
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            decoration: BoxDecoration(
                              color: _activeImageIndex == i
                                  ? AppColors.primary
                                  : Colors.white70,
                              borderRadius: BorderRadius.circular(3),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),

          if (imageUrls.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 88,
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  scrollDirection: Axis.horizontal,
                  itemCount: imageUrls.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final isActive = index == _activeImageIndex;
                    return Semantics(
                      button: true,
                      selected: isActive,
                      label: '${index + 1} / ${imageUrls.length}',
                      child: GestureDetector(
                        onTap: () => _imagePageController.animateToPage(
                          index,
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeInOut,
                        ),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          width: 68,
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isActive
                                  ? AppColors.primary
                                  : Colors.transparent,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(7),
                            child: Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest
                                  .withValues(alpha: 0.3),
                              child: CachedNetworkImage(
                                imageUrl: imageUrls[index],
                                fit: BoxFit.contain,
                                alignment: Alignment.center,
                                filterQuality: FilterQuality.high,
                                placeholder: (_, __) => Container(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .surfaceContainerHighest,
                                ),
                                errorWidget: (_, __, ___) => const Icon(
                                  Icons.broken_image_outlined,
                                  color: AppColors.muted,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),

          // شريط التنزيلات الخاطفة (Flash Sale Banner)
          if (product.hasActiveDeal)
            SliverToBoxAdapter(child: _buildFlashSaleBanner(product)),

          // كوبون البائع (Store Coupon Banner)
          const SliverToBoxAdapter(child: SizedBox.shrink()),

          // بطاقة التوصيل المتوقع (Estimated Shipping Card)
          SliverToBoxAdapter(child: _buildShippingCard(product)),

          // تفاصيل المنتج بطراز ترينديول
          SliverToBoxAdapter(
            child: Container(
              color: Theme.of(context).colorScheme.surface,
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // اسم البائع والتصنيف
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      AppText(
                        product.vendor?.storeName ??
                            product.category?.name ??
                            'تريند شام',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                      if (product.discountPercentage != null &&
                          product.discountPercentage! > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                              color: AppColors.danger,
                              borderRadius: BorderRadius.circular(4)),
                          child: AppText(
                            '%${product.discountPercentage} خصم خاص',
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // اسم المنتج
                  AppText(
                    product.name,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onSurface),
                  ),
                  const SizedBox(height: 8),

                  // التقييمات والنجوم
                  Row(
                    children: [
                      const Icon(Icons.star,
                          color: AppColors.ratingStar, size: 18),
                      const SizedBox(width: 4),
                      if (product.averageRating != null &&
                          product.reviewsCount > 0) ...[
                        AppText(
                          product.averageRating!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        const SizedBox(width: 4),
                        AppText(
                          '${product.reviewsCount} تقييم',
                          style: const TextStyle(
                              color: AppColors.muted, fontSize: 12),
                        ),
                      ] else if (product.reviewsCount == 0)
                        const AppText(
                          'لا توجد تقييمات حتى الآن',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        )
                      else
                        const AppText(
                          'التقييمات غير متاحة حالياً',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 12),
                        ),
                      const Spacer(),
                      Row(
                        children: [
                          const Icon(Icons.bolt,
                              color: AppColors.primary, size: 16),
                          const SizedBox(width: 2),
                          AppText(
                            _hasVariants
                                ? ((_selectedVariant?.stockQuantity ?? 0) > 0
                                    ? 'متوفر (${_selectedVariant!.stockQuantity})'
                                    : 'غير متوفر')
                                : (product.inStock
                                    ? 'متوفر بالمخزون'
                                    : 'غير متوفر'),
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: (_hasVariants
                                      ? ((_selectedVariant?.stockQuantity ??
                                              0) >
                                          0)
                                      : product.inStock)
                                  ? Colors.green.shade700
                                  : AppColors.danger,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // سعر المنتج
                  if (product.hasActiveDeal)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                            color: const Color(0xFFFFF3E0),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color:
                                    AppColors.primary.withValues(alpha: 0.25))),
                        child: AppText(
                            product.displayDiscountPercentage != null
                                ? '${product.dealLabel ?? 'عرض اليوم'} • خصم %${product.displayDiscountPercentage}'
                                : (product.dealLabel ?? 'عرض اليوم'),
                            style: const TextStyle(
                                color: AppColors.primaryDark,
                                fontSize: 11,
                                fontWeight: FontWeight.bold)),
                      ),
                    ),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AppText(
                        '${_effectiveUnitPrice.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            color: AppColors.primary),
                      ),
                      if (product.formattedCompareAtPrice != null &&
                          !_hasVariants) ...[
                        const SizedBox(width: 8),
                        AppText(
                          product.formattedCompareAtPrice!,
                          style: const TextStyle(
                              fontSize: 15,
                              color: AppColors.muted,
                              decoration: TextDecoration.lineThrough),
                        ),
                      ],
                    ],
                  ),
                  if (product.willEarnPoints > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(children: [
                        const Icon(Icons.diamond_outlined, size: 16, color: Color(0xFF9A7425)),
                        const SizedBox(width: 4),
                        AppText('ستكسب ${pointsLabel(product.willEarnPoints)} عند استلام الطلب',
                            style: const TextStyle(color: Color(0xFF9A7425), fontSize: 13)),
                      ]),
                    ),
                  if (product.storeCoupons.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StoreCouponsStrip(coupons: product.storeCoupons),
                    ),
                  const SizedBox(height: 14),

                  if (_hasVariants) ...[
                    if (_colorKeys.isNotEmpty) ...[
                      const AppText('اللون',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _colorKeys.map((hex) {
                          final v = _variants.firstWhere((x) => x.color == hex);
                          final selected = _selectedColor == hex;
                          final Color? swatch =
                              colorFromHex(v.colorHex ?? v.color);
                          final available = _variants.any(
                              (x) => x.color == hex && x.stockQuantity > 0);
                          return GestureDetector(
                            onTap: available ? () => _selectColor(hex) : null,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                    color: selected
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .outlineVariant,
                                    width: selected ? 2 : 1),
                                color: available
                                    ? null
                                    : Theme.of(context)
                                        .colorScheme
                                        .surfaceContainerHighest
                                        .withValues(alpha: 0.4),
                              ),
                              child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                        width: 16,
                                        height: 16,
                                        decoration: BoxDecoration(
                                            color: swatch,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                                color: swatch == null
                                                    ? AppColors.muted
                                                    : Colors.black12))),
                                    const SizedBox(width: 6),
                                    AppText(v.colorName ?? hex,
                                        style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: selected
                                                ? FontWeight.bold
                                                : FontWeight.w500,
                                            color: available
                                                ? null
                                                : AppColors.muted,
                                            decoration: available
                                                ? null
                                                : TextDecoration.lineThrough)),
                                  ]),
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_sizeKeys.isNotEmpty) ...[
                      const AppText('المقاس',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _sizeKeys.map((sz) {
                          final selected = _selectedSize == sz;
                          final available = _variants.any((x) =>
                              x.size == sz &&
                              (_selectedColor == null ||
                                  x.color == _selectedColor) &&
                              x.stockQuantity > 0);
                          return ChoiceChip(
                            label: AppText(sz),
                            selected: selected,
                            onSelected:
                                available ? (_) => _selectSize(sz) : null,
                            selectedColor:
                                AppColors.primary.withValues(alpha: 0.15),
                            labelStyle: TextStyle(
                                fontWeight: selected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: available ? null : AppColors.muted),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ],

                  // حدد الكمية المطلوبة - تفاعلي
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context)
                            .colorScheme
                            .outlineVariant
                            .withValues(alpha: 0.5),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        AppText(
                          'تحديد الكمية المطلوبة:',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.onSurface,
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surface,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.primary.withValues(alpha: 0.35),
                            ),
                          ),
                          child: Row(
                            children: [
                              InkWell(
                                onTap: _selectedQuantity > 1
                                    ? () => setState(() => _selectedQuantity--)
                                    : null,
                                borderRadius: const BorderRadius.horizontal(
                                    right: Radius.circular(10)),
                                child: Padding(
                                  padding: const EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.remove_rounded,
                                    size: 18,
                                    color: _selectedQuantity > 1
                                        ? AppColors.primary
                                        : Theme.of(context)
                                            .colorScheme
                                            .onSurfaceVariant
                                            .withValues(alpha: 0.4),
                                  ),
                                ),
                              ),
                              Container(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 12),
                                child: AppText(
                                  '$_selectedQuantity',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                    color:
                                        Theme.of(context).colorScheme.onSurface,
                                  ),
                                ),
                              ),
                              InkWell(
                                onTap: () => setState(() {
                                  final max = _hasVariants
                                      ? (_selectedVariant?.stockQuantity ?? 0)
                                      : 999;
                                  if (_selectedQuantity < max) {
                                    _selectedQuantity++;
                                  }
                                }),
                                borderRadius: const BorderRadius.horizontal(
                                    left: Radius.circular(10)),
                                child: const Padding(
                                  padding: EdgeInsets.all(6),
                                  child: Icon(
                                    Icons.add_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // صندوق البائع على طريقة ترينديول
          if (product.vendor != null)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.storefront,
                          color: AppColors.primary, size: 24),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            product.vendor!.storeName,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              AppText(
                                'تقييم المتجر: ',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                              const AppText(
                                '9.6 ⚡',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    OutlinedButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StoreScreen(storeId: product.vendor!.id),
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        side: const BorderSide(color: AppColors.primary),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(6)),
                      ),
                      child: const AppText('زيارة المتجر',
                          style: TextStyle(
                              color: AppColors.primary, fontSize: 12)),
                    ),
                  ],
                ),
              ),
            ),

          // صندوق الشحن والتوصيل
          SliverToBoxAdapter(
            child: ScaleTapContainer(
              onTap: () {},
              child: Container(
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Row(
                  children: [
                    const Icon(Icons.local_shipping_outlined,
                        color: AppColors.primary, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'شحن سريع وتوصيل آمن',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          AppText(
                            'يصلك خلال 24 - 48 ساعة مع إمكانية الدفع عند الاستلام',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // وصف المنتج
          if (product.description != null && product.description!.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.only(top: 10, bottom: 20),
                padding: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.surface,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(
                      'تفاصيل المنتج والوصف',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppText(
                      product.description!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 13,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          _buildReviewsSection(),

          SliverToBoxAdapter(
            key: _questionsAnchor,
            child: ProductQuestionsSection(slug: widget.slug),
          ),

          if (_recommendationsError != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: AppText(
                  _recommendationsError!,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12),
                ),
              ),
            ),
          if (_similarProducts.isNotEmpty)
            _buildRecommendationSection('منتجات مشابهة', _similarProducts),
          if (_popularProducts.isNotEmpty)
            _buildRecommendationSection('الأكثر مبيعاً', _popularProducts),
        ],
      ),

      // الشريط السفلي العائم للسلّة بتقنية Glassmorphism - محمية تماماً ضد التداخل والـ Overflow
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          margin: const EdgeInsets.fromLTRB(10, 4, 10, 6),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      blurRadius: 16,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            'السعر الإجمالي',
                            style: TextStyle(
                              fontSize: 11,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: AppText(
                              _selectedQuantity > 1
                                  ? _formattedTotalPrice
                                  : ' ل.س',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? AppColors.gold
                                    : AppColors.brandGreen,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // زر اشتر الآن
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ScaleTapContainer(
                          onTap: (!_isOutOfStock && !_isAddingToCart)
                              ? () async {
                                  final nav = Navigator.of(context);
                                  await _addToCart();
                                  if (!mounted) return;
                                  nav.push(MaterialPageRoute(
                                      builder: (_) => const CartScreen()));
                                }
                              : () {},
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: isDark
                                    ? const Color(0xFF8CCFB4)
                                    : AppColors.brandGreen,
                                width: 1.5,
                              ),
                            ),
                            child: Center(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.flash_on_rounded,
                                          size: 16,
                                          color: isDark
                                              ? const Color(0xFF8CCFB4)
                                              : AppColors.brandGreen),
                                      const SizedBox(width: 2),
                                      AppText(
                                        'اشتر الآن',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 12.5,
                                          color: isDark
                                              ? const Color(0xFF8CCFB4)
                                              : AppColors.brandGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // زر أضف إلى السلة مع تدرج لوني
                    Expanded(
                      child: SizedBox(
                        height: 44,
                        child: ScaleTapContainer(
                          onTap: (!_isOutOfStock && !_isAddingToCart)
                              ? () => _addToCart(sourceKey: _addToCartButtonKey)
                              : () {},
                          child: Container(
                            key: _addToCartButtonKey,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(
                                colors: !_isOutOfStock
                                    ? (isDark
                                        ? [
                                            AppColors.brandGreenLight,
                                            AppColors.brandGreen
                                          ]
                                        : [
                                            AppColors.brandGreen,
                                            AppColors.brandGreenLight
                                          ])
                                    : [Colors.grey, Colors.grey.shade600],
                              ),
                              boxShadow: [
                                if (!_isOutOfStock)
                                  BoxShadow(
                                    color: AppColors.brandGreen
                                        .withValues(alpha: 0.35),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                              ],
                            ),
                            child: Center(
                              child: _isAddingToCart
                                  ? const SizedBox(
                                      height: 16,
                                      width: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Padding(
                                        padding:
                                            EdgeInsets.symmetric(horizontal: 4),
                                        child: Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Icon(Icons.shopping_bag_outlined,
                                                size: 16, color: Colors.white),
                                            SizedBox(width: 2),
                                            AppText(
                                              'أضف للسلة',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: Colors.white,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _appBarAction({
    required Widget icon,
    required Color iconColor,
    required VoidCallback onPressed,
    required String tooltip,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface.withValues(alpha: 0.9),
        shape: BoxShape.circle,
        border: Border.all(color: iconColor.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: IconButton(
        tooltip: tooltip,
        icon: icon,
        color: iconColor,
        onPressed: onPressed,
        splashRadius: 22,
      ),
    );
  }

  Widget _buildReviewsSection() {
    return SliverToBoxAdapter(
      child: Container(
        color: Theme.of(context).colorScheme.surface,
        child: ProductReviewsSection(
          averageRating: _product?.averageRating,
          reviewsCount: _product?.reviewsCount ?? 0,
          reviews: _reviews,
          isLoading: _isLoadingReviews,
          isLoadingMore: _isLoadingMoreReviews,
          hasNextPage: _reviewsPage < _reviewsLastPage,
          error: _reviewsError,
          onRetry: () => _loadReviews(reset: true),
          onLoadMore: () => _loadReviews(),
          onAddReview: (rating, comment) async {
            await _productService.addReview(widget.slug,
                rating: rating, comment: comment);
            await _loadReviews(reset: true);
            final updatedProduct = await _productService.show(widget.slug);
            if (mounted) {
              setState(() {
                _product = updatedProduct;
              });
            }
          },
        ),
      ),
    );
  }

  Widget _buildRecommendationSection(String title, List<Product> products) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.only(top: 16, bottom: 12),
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: AppText(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 290,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) {
                  final suggestedProduct = products[index];
                  return SizedBox(
                    width: 168,
                    child: ProductCard(
                      product: suggestedProduct,
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProductDetailScreen(
                            slug: suggestedProduct.slug,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFlashSaleBanner(Product product) {
    final endsAt = product.dealEndsAt;
    final discount = product.displayDiscountPercentage;
    final timeText = endsAt != null
        ? 'ينتهي ${endsAt.day}/${endsAt.month} ${endsAt.hour.toString().padLeft(2, '0')}:${endsAt.minute.toString().padLeft(2, '0')}'
        : (product.dealLabel ?? 'عرض محدود');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
            colors: [Color(0xFFFF5722), Color(0xFFE91E63)],
            begin: Alignment.centerRight,
            end: Alignment.centerLeft),
      ),
      child: Row(
        children: [
          const Icon(Icons.flash_on, color: Colors.white, size: 22),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                    discount != null
                        ? 'عرض اليوم • خصم %$discount'
                        : 'عرض اليوم',
                    style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14)),
                const AppText('السعر المخفّض مطبق على هذا المنتج الآن.',
                    style: TextStyle(color: Colors.white70, fontSize: 11)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(8)),
            child: AppText(timeText,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildShippingCard(Product product) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 10, 16, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.local_shipping_outlined,
              color: AppColors.primary, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                  'شحن وتوصيل',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                AppText(
                  _isOutOfStock
                      ? 'هذا المنتج/الخيار غير متوفر حالياً.'
                      : 'متوفر للشحن. راجع تفاصيل التوصيل عند إتمام الطلب.',
                  style: TextStyle(
                    fontSize: 11,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
