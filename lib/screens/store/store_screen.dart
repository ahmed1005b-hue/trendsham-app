import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../../widgets/social_brand.dart';
import 'dart:async';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../models/store_coupon.dart';
import '../../models/vendor.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_exception.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/store_service.dart';
import '../../services/notification_settings_service.dart';
import '../../utils/auth_prompt.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/product_card.dart';
import '../../widgets/seller_reviews_section.dart';
import '../../widgets/store_coupons_strip.dart';
import '../product/product_detail_screen.dart';
import '../messages/buyer_seller_messages_screen.dart';
import '../../widgets/shimmer_loading.dart';

class StoreScreen extends StatefulWidget {
  final int storeId;

  const StoreScreen({super.key, required this.storeId});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  final StoreService _storeService = StoreService();
  Vendor? _store;
  final List<Product> _products = [];
  List<Product> _bestSelling = [];
  List<Product> _recentArrivals = [];
  List<Product> _similarProducts = [];
  List<StoreCoupon> _coupons = [];
  final Set<int> _favoriteIds = {};
  final Map<int, Product> _comparison = {};
  final TextEditingController _priceMinController = TextEditingController();
  final TextEditingController _priceMaxController = TextEditingController();
  final FavoriteService _favoriteService = FavoriteService();
  Timer? _filterDebounce;
  double? _ratingMin;
  bool _inStockOnly = false;
  bool _following = false;
  bool _filterLoading = false;
  String? _filterError;
  String? _error;
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  bool _loading = true;
  bool _loadingMore = false;

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _priceMinController.dispose();
    _priceMaxController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _loadStore();
    _loadFavorites();
  }

  Future<void> _loadFavorites() async {
    if (context.read<AuthProvider>().user?.role != 'customer') {
      return;
    }
    try {
      final favorites = await _favoriteService.list();
      if (mounted) {
        setState(() => _favoriteIds.addAll(favorites.map((p) => p.id)));
      }
    } catch (_) {
      // The public store remains usable if the optional favorites request fails.
    }
  }

  Future<void> _loadStore() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await _storeService.show(widget.storeId);
      if (!mounted) return;
      setState(() {
        _store = result.store;
        _products
          ..clear()
          ..addAll(result.products);
        _bestSelling = result.bestSelling;
        _recentArrivals = result.recentArrivals;
        _similarProducts = result.similarProducts;
        _coupons = result.coupons;
        _following = result.store.isFollowed;
        _favoriteIds.addAll(
            result.products.where((p) => p.isFavorited).map((p) => p.id));
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المتجر: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _storeService.show(
        widget.storeId,
        page: _page + 1,
        priceMin: double.tryParse(_priceMinController.text),
        priceMax: double.tryParse(_priceMaxController.text),
        ratingMin: _ratingMin,
        inStock: _inStockOnly,
      );
      if (!mounted) return;
      setState(() {
        _products.addAll(result.products);
        _page = result.currentPage;
        _lastPage = result.lastPage;
      });
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText('تعذّر تحميل المزيد من المنتجات: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _applyFilters() async {
    final minimum = double.tryParse(_priceMinController.text);
    final maximum = double.tryParse(_priceMaxController.text);
    if ((_priceMinController.text.isNotEmpty && minimum == null) ||
        (_priceMaxController.text.isNotEmpty && maximum == null) ||
        (minimum != null && maximum != null && minimum > maximum)) {
      setState(() => _filterError = 'تحقق من نطاق السعر.');
      return;
    }
    setState(() {
      _filterLoading = true;
      _filterError = null;
    });
    try {
      final result = await _storeService.show(
        widget.storeId,
        priceMin: minimum,
        priceMax: maximum,
        ratingMin: _ratingMin,
        inStock: _inStockOnly,
      );
      if (!mounted) return;
      setState(() {
        _products
          ..clear()
          ..addAll(result.products);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _total = result.total;
        _favoriteIds.addAll(
            result.products.where((p) => p.isFavorited).map((p) => p.id));
        _similarProducts = result.similarProducts;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _filterError = e.message);
    } catch (_) {
      if (mounted) setState(() => _filterError = 'تعذّر تحديث المنتجات.');
    } finally {
      if (mounted) setState(() => _filterLoading = false);
    }
  }

  void _queueFilter() {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 350), _applyFilters);
  }

  Future<void> _toggleFavorite(Product product) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await showAuthRequiredDialog(context);
      return;
    }
    if (auth.user?.role != 'customer') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('المفضلة متاحة لحسابات العملاء.')),
      );
      return;
    }
    final wasFavorite =
        _favoriteIds.contains(product.id) || product.isFavorited;
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
    });
    try {
      final favorited = await _favoriteService.toggle(product.id);
      if (mounted) {
        setState(() {
          if (favorited) {
            _favoriteIds.add(product.id);
          } else {
            _favoriteIds.remove(product.id);
          }
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          if (wasFavorite) {
            _favoriteIds.add(product.id);
          } else {
            _favoriteIds.remove(product.id);
          }
        });
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _toggleFollow() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await showAuthRequiredDialog(context);
      return;
    }
    if (auth.user?.role != 'customer') return;
    try {
      final result = await _storeService.followToggle(widget.storeId);
      final following = result.followed;
      if (mounted) setState(() => _following = following);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: AppText(
                  following ? 'بدأت متابعة المتجر.' : 'ألغيت متابعة المتجر.')),
        );
      }
      if (result.askOffersOptIn && mounted) await _askOffersOptIn();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  /// أول متابعة لمتجر: سؤال واحد عن إشعارات العروض.
  Future<void> _askOffersOptIn() async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.local_offer_outlined),
        title: const AppText('إشعارات العروض'),
        content: const AppText(
          'هل تريد إشعارات عروض ومنتجات المتاجر التي تتابعها؟\n'
          'حتى 3 يومياً، ولا شيء ليلاً. يمكنك تغيير ذلك من إعدادات الإشعارات.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('لا، شكراً'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('نعم'),
          ),
        ],
      ),
    );
    if (yes == null) return;
    try {
      await NotificationSettingsService().update({'offers': yes});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content:
                AppText('تعذّر حفظ اختيارك، غيّره من إعدادات الإشعارات.')));
      }
    }
  }

  Future<void> _messageSeller() async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      await showAuthRequiredDialog(context);
      return;
    }
    if (auth.user?.role != 'customer') return;
    try {
      final conversationId =
          await _storeService.startConversation(widget.storeId);
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(
        builder: (_) =>
            BuyerSellerMessagesScreen(conversationId: conversationId),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  void _openProduct(Product product, {bool openQuestions = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
          builder: (_) => ProductDetailScreen(
                slug: product.slug,
                openQuestions: openQuestions,
              )),
    );
  }

  void _toggleComparison(Product product) {
    setState(() {
      if (_comparison.containsKey(product.id)) {
        _comparison.remove(product.id);
      } else if (_comparison.length >= 4) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: AppText('يمكنك مقارنة أربعة منتجات كحد أقصى.')),
        );
      } else {
        _comparison[product.id] = product;
      }
    });
  }

  void _showComparison() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('مقارنة المنتجات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
              const SizedBox(height: 12),
              for (final product in _comparison.values) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: AppText(product.name),
                  subtitle: AppText(
                    '${product.formattedPrice} · ${product.averageRating?.toStringAsFixed(1) ?? 'لا تقييم'} · ${product.inStock ? 'متوفر' : 'غير متوفر'} · ${product.category?.name ?? 'غير مصنف'}',
                  ),
                  trailing: IconButton(
                    tooltip: context.tr('إزالة من المقارنة'),
                    onPressed: () =>
                        setState(() => _comparison.remove(product.id)),
                    icon: const Icon(Icons.close),
                  ),
                ),
                const Divider(height: 1),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showImageZoom(Product product) {
    final imageUrl = product.primaryImage?.url;
    if (imageUrl == null || imageUrl.isEmpty) return;
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
                  errorWidget: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: Colors.white,
                    size: 48,
                  ),
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

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppText('تصفية المنتجات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _priceMinController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.tr('السعر من'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _queueFilter(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _priceMaxController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: context.tr('السعر إلى'),
                        isDense: true,
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (_) => _queueFilter(),
                    ),
                  ),
                ],
              ),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<double>(
                      initialValue: _ratingMin,
                      decoration: InputDecoration(
                        labelText: context.tr('أقل تقييم'),
                        isDense: true,
                      ),
                      items: const [
                        DropdownMenuItem(
                            value: null, child: AppText('أي تقييم')),
                        DropdownMenuItem(value: 3, child: AppText('٣+')),
                        DropdownMenuItem(value: 4, child: AppText('٤+')),
                        DropdownMenuItem(value: 4.5, child: AppText('٤.٥+')),
                      ],
                      onChanged: (value) {
                        setState(() => _ratingMin = value);
                        _applyFilters();
                      },
                    ),
                  ),
                  Expanded(
                    child: CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      value: _inStockOnly,
                      title: const AppText('المتوفر فقط',
                          style: TextStyle(fontSize: 12)),
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (value) {
                        setState(() => _inStockOnly = value ?? false);
                        _applyFilters();
                      },
                    ),
                  ),
                ],
              ),
              if (_filterLoading)
                const LinearProgressIndicator(minHeight: 2)
              else if (_filterError != null)
                AppText(_filterError!,
                    style: const TextStyle(color: AppColors.danger)),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () {
                    _priceMinController.clear();
                    _priceMaxController.clear();
                    setState(() {
                      _ratingMin = null;
                      _inStockOnly = false;
                      _filterError = null;
                    });
                    _applyFilters();
                  },
                  child: const AppText('مسح الفلاتر'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText(_store?.storeName ?? 'المتجر')),
      bottomNavigationBar: _comparison.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(10),
                child: OutlinedButton.icon(
                  onPressed: _comparison.length < 2 ? null : _showComparison,
                  icon: const Icon(Icons.compare_arrows),
                  label: AppText('مقارنة ${_comparison.length} منتجات'),
                ),
              ),
            ),
      body: _loading
          ? const StoreSkeleton()
          : _error != null
              ? AppStateMessage(
                  message: _error!,
                  icon: Icons.store_outlined,
                  onRetry: _loadStore,
                )
              : RefreshIndicator(
                  onRefresh: _loadStore,
                  child: CustomScrollView(
                    slivers: [
                      SliverToBoxAdapter(child: _buildStoreHeader(_store!)),
                      SliverToBoxAdapter(
                          child: StoreCouponsStrip(coupons: _coupons)),
                      // ===== تقييمات البائع (نجوم المتجر) =====
                      SliverToBoxAdapter(
                        child: SellerReviewsSection(storeId: widget.storeId),
                      ),
                      SliverToBoxAdapter(
                        child: _buildFeaturedSection(
                          'الأكثر مبيعاً',
                          _bestSelling,
                        ),
                      ),
                      SliverToBoxAdapter(
                        child: _buildFeaturedSection(
                          'وصل حديثاً',
                          _recentArrivals,
                        ),
                      ),
                      SliverToBoxAdapter(child: _buildFilters()),
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 4,
                                    height: 18,
                                    decoration: BoxDecoration(
                                      color: AppColors.primary,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const AppText(
                                    'منتجات المتجر',
                                    style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: context.mutedSurface,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: context.softBorder),
                                ),
                                child: AppText(
                                  '$_total منتج',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.muted,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_products.isEmpty)
                        const SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                              child: AppText('لا توجد منتجات متاحة حالياً.')),
                        )
                      else
                        SliverPadding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          sliver: SliverGrid.builder(
                            itemCount: _products.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisSpacing: 10,
                              crossAxisSpacing: 10,
                              childAspectRatio: 0.56,
                            ),
                            itemBuilder: (context, index) => ProductCard(
                              product: _products[index],
                              onTap: () => _openProduct(_products[index]),
                              isFavorited:
                                  _favoriteIds.contains(_products[index].id) ||
                                      _products[index].isFavorited,
                              onFavoriteTap: () =>
                                  _toggleFavorite(_products[index]),
                              onImageTap: () =>
                                  _showImageZoom(_products[index]),
                              onQuestionsTap: () => _openProduct(
                                _products[index],
                                openQuestions: true,
                              ),
                              onCompareTap: () =>
                                  _toggleComparison(_products[index]),
                            ),
                          ),
                        ),
                      if (_page < _lastPage)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: OutlinedButton(
                              onPressed: _loadingMore ? null : _loadMore,
                              child: _loadingMore
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2),
                                    )
                                  : const AppText('تحميل المزيد'),
                            ),
                          ),
                        ),
                      const SliverToBoxAdapter(child: SizedBox(height: 20)),
                      if (_similarProducts.isNotEmpty)
                        SliverToBoxAdapter(
                          child: _buildFeaturedSection(
                            'منتجات مشابهة في هذا المتجر',
                            _similarProducts,
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildStoreHeader(Vendor store) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // غلاف المتجر مع الشعار المتداخل بأسلوب ترينديول
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.bottomRight,
          children: [
            // صورة الغلاف العريضة
            SizedBox(
              height: 180,
              width: double.infinity,
              child: store.storeBanner != null && store.storeBanner!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: store.storeBanner!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => _bannerPlaceholder(),
                      placeholder: (_, __) => _bannerPlaceholder(),
                    )
                  : _bannerPlaceholder(),
            ),
            // تدرج لزيادة وضوح العناصر إن وجد
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.3)
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        // معلومات المتجر والشعار المتداخل
        Container(
          color: Theme.of(context).colorScheme.surface,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // الشعار الدائري المتداخل للأعلى قليلاً
                  Transform.translate(
                    offset: const Offset(0, -30),
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 8,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 72,
                          height: 72,
                          child: store.storeLogo != null
                              ? CachedNetworkImage(
                                  imageUrl: store.storeLogo!,
                                  fit: BoxFit.cover,
                                  errorWidget: (_, __, ___) => Container(
                                    color: AppColors.goldSoft,
                                    child: const Icon(Icons.storefront,
                                        color: AppColors.primary, size: 32),
                                  ),
                                  placeholder: (_, __) => Container(
                                    color: AppColors.goldSoft,
                                    child: const Icon(Icons.storefront,
                                        color: AppColors.primary, size: 32),
                                  ),
                                )
                              : Container(
                                  color: AppColors.goldSoft,
                                  child: const Icon(Icons.storefront,
                                      color: AppColors.primary, size: 32),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // اسم المتجر وزر التواصل أو المتابعة
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Expanded(
                              child: AppText(
                                store.storeName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.verified,
                                      color: AppColors.primary, size: 14),
                                  SizedBox(width: 4),
                                  AppText(
                                    'متجر موثوق',
                                    style: TextStyle(
                                      color: AppColors.primary,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              // وصف المتجر
              if (store.storeDescription?.isNotEmpty == true) ...[
                const SizedBox(height: 6),
                AppText(
                  store.storeDescription!,
                  style: const TextStyle(
                    color: AppColors.muted,
                    fontSize: 13,
                    height: 1.3,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (store.businessHoursStatus != null)
                    Chip(
                      avatar: Icon(
                        store.businessHoursStatus!['state'] == 'open'
                            ? Icons.schedule
                            : Icons.schedule_outlined,
                        size: 16,
                        color: store.businessHoursStatus!['state'] == 'open'
                            ? AppColors.primary
                            : AppColors.muted,
                      ),
                      label: AppText(
                        store.businessHoursStatus!['label']?.toString() ??
                            'أوقات العمل غير محددة',
                      ),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (context.read<AuthProvider>().user?.role == 'customer')
                    OutlinedButton.icon(
                      onPressed: _toggleFollow,
                      icon: Icon(_following
                          ? Icons.notifications_active
                          : Icons.notifications_none),
                      label:
                          AppText(_following ? 'تتابع المتجر' : 'تابع المتجر'),
                    ),
                  if (context.read<AuthProvider>().user?.role == 'customer')
                    OutlinedButton.icon(
                      onPressed: _messageSeller,
                      icon: const Icon(Icons.chat_outlined),
                      label: const AppText('راسل البائع'),
                    ),
                ],
              ),
              if (store.storeContactPhone?.isNotEmpty == true ||
                  store.storeWhatsapp?.isNotEmpty == true ||
                  store.storeInstagram?.isNotEmpty == true) ...[
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (store.storeContactPhone?.isNotEmpty == true)
                      OutlinedButton.icon(
                        onPressed: () => _launchContact(
                            'tel:${store.storeContactPhone!.replaceAll(RegExp(r"[^0-9+]"), "")}'),
                        icon: const Icon(Icons.phone_outlined, size: 17),
                        label: const AppText('اتصال'),
                      ),
                    if (store.storeWhatsapp?.isNotEmpty == true)
                      _brandButton('whatsapp', 'واتساب',
                          () => _launchContact(store.storeWhatsapp)),
                    if (store.storeInstagram?.isNotEmpty == true)
                      _brandButton('instagram', 'إنستغرام',
                          () => _launchContact(store.storeInstagram)),
                  ],
                ),
              ],
              if (store.businessHours?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _storeInformation('أوقات العمل', store.businessHours!),
              ],
              if (store.shippingPolicy?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _storeInformation('سياسة الشحن', store.shippingPolicy!),
              ],
              if (store.returnPolicy?.isNotEmpty == true) ...[
                const SizedBox(height: 10),
                _storeInformation('الإرجاع والاستبدال', store.returnPolicy!),
              ],
              const SizedBox(height: 8),
              // إحصائيات سريعة (عدد المنتجات والتقييم)
              Row(
                children: [
                  const Icon(Icons.inventory_2_outlined,
                      size: 14, color: AppColors.muted),
                  const SizedBox(width: 4),
                  AppText(
                    '$_total منتج متاح',
                    style:
                        const TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                  const SizedBox(width: 16),
                  Icon(
                    Icons.star_rounded,
                    size: 16,
                    color: store.sellerRating == null
                        ? AppColors.muted
                        : AppColors.ratingStar,
                  ),
                  const SizedBox(width: 2),
                  AppText(
                    store.sellerRating == null
                        ? 'لا توجد تقييمات بعد'
                        : r'${rating} (${count} تقييم)'
                            .replaceFirst(r'${rating}',
                                store.sellerRating!.toStringAsFixed(1))
                            .replaceFirst(
                                r'${count}', '${store.sellerReviewsCount}'),
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: AppColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _storeInformation(String title, String value) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppText(title,
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          const SizedBox(height: 4),
          AppText(value, style: const TextStyle(height: 1.45)),
        ],
      ),
    );
  }

  Widget _buildFeaturedSection(String title, List<Product> products) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: AppText(title,
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          if (products.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppText('لا توجد منتجات متاحة حالياً.',
                  style: TextStyle(color: AppColors.muted)),
            )
          else
            SizedBox(
              height: 255,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                scrollDirection: Axis.horizontal,
                itemCount: products.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, index) => SizedBox(
                  width: 158,
                  child: ProductCard(
                    product: products[index],
                    onTap: () => _openProduct(products[index]),
                    isFavorited: _favoriteIds.contains(products[index].id) ||
                        products[index].isFavorited,
                    onFavoriteTap: () => _toggleFavorite(products[index]),
                    onImageTap: () => _showImageZoom(products[index]),
                    onQuestionsTap: () =>
                        _openProduct(products[index], openQuestions: true),
                    onCompareTap: () => _toggleComparison(products[index]),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// زر تواصل بشعار الموقع الحقيقي ولونه الأصلي (واتساب أخضر، إنستغرام بتدرّجه)
  Widget _brandButton(String key, String label, VoidCallback onTap) {
    final brand = SocialBrand.of(key);
    return Material(
      key: ValueKey('store-$key'),
      color: Colors.transparent,
      child: Ink(
        decoration: BoxDecoration(
          color: brand.gradient == null ? brand.color : null,
          gradient: brand.gradient,
          borderRadius: BorderRadius.circular(10),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              FaIcon(brand.icon, size: 16, color: Colors.white),
              const SizedBox(width: 8),
              AppText(label,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.bold)),
            ]),
          ),
        ),
      ),
    );
  }

  Future<void> _launchContact(String? link) async {
    if (link == null || link.trim().isEmpty) return;
    final uri = Uri.tryParse(link.trim());
    if (uri == null) return;
    final safe = uri.scheme == 'tel' ||
        ((uri.scheme == 'http' || uri.scheme == 'https') &&
            uri.host.isNotEmpty);
    if (safe) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Widget _bannerPlaceholder() {
    return Container(
      color: AppColors.primary.withValues(alpha: 0.08),
      child: const Center(
        child:
            Icon(Icons.storefront_rounded, size: 48, color: AppColors.primary),
      ),
    );
  }
}
