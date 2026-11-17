import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_switcher.dart';

import '../../config/api_config.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/category.dart';
import '../../models/coupon_story.dart';
import '../../models/product.dart';
import '../../providers/auth_provider.dart';
import '../../screens/category/category_products_screen.dart';
import '../../screens/chat/chat_screen.dart';
import '../../screens/notifications/notifications_screen.dart';
import '../../screens/product/product_detail_screen.dart';
import '../../screens/search/search_screen.dart';
import '../../screens/store/store_screen.dart';
import '../../services/api_exception.dart';
import '../../services/product_service.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/showcase_service.dart';
import '../../utils/add_to_cart_fly.dart';
import '../../utils/auth_prompt.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/product_card.dart';
import '../../widgets/quick_view_bottom_sheet.dart';
import '../../widgets/shimmer_loading.dart';
import '../../services/recently_viewed_store.dart';
import '../../widgets/showcase_section.dart';
import '../../widgets/story_viewer.dart';
import '../../widgets/brand_wordmark.dart';

part 'home_tab_widgets.dart';

class HomeTab extends StatefulWidget {
  const HomeTab({
    super.key,
    this.productService,
    this.categoryService,
    this.storyService,
    this.favoriteService,
    this.showcaseService,
  });

  final ProductService? productService;
  final CategoryService? categoryService;
  final StoryService? storyService;
  final FavoriteService? favoriteService;
  final ShowcaseService? showcaseService;

  @override
  State<HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<HomeTab> {
  late final ProductService _productService =
      widget.productService ?? ProductService();
  late final CategoryService _categoryService =
      widget.categoryService ?? CategoryService();
  late final StoryService _storyService = widget.storyService ?? StoryService();
  late final FavoriteService _favoriteService =
      widget.favoriteService ?? FavoriteService();
  late final ShowcaseService _showcaseService =
      widget.showcaseService ?? ShowcaseService();

  List<Product>? _products;
  List<ShowcaseData> _showcases = const [];
  List<Category>? _categories;
  List<StoryModel>? _stories;
  List<Product>? _dailyDealProducts;
  List<Product> _recentProducts = const [];
  bool _dailyDealsLoading = false;
  String? _dailyDealsError;
  final Set<int> _favoriteIds = {};
  String? _productsError;
  String? _categoriesError;

  /// عروض اليوم الحقيقية من جدول daily_deals (أولوية أولى)،
  /// وإذا لا يوجد نرجع للمنتجات ذات الخصم الدائم.
  List<Product> get _deals {
    final dealProducts = _dailyDealProducts ?? const <Product>[];
    if (dealProducts.isNotEmpty) return dealProducts;
    final products = _products ?? const <Product>[];
    final actualDeals = products
        .where((product) =>
            (product.discountPercentage ?? 0) > 0 ||
            (product.compareAtPrice != null &&
                product.compareAtPrice! > product.price))
        .toList();
    if (actualDeals.isNotEmpty) return actualDeals;
    return products.take(6).toList();
  }

  bool get _hasDailyDealProducts =>
      (_dailyDealProducts ?? const <Product>[]).isNotEmpty;

  @override
  void initState() {
    super.initState();
    RecentlyViewedStore.changes.addListener(_loadRecent);
    _load();
  }

  @override
  void dispose() {
    RecentlyViewedStore.changes.removeListener(_loadRecent);
    super.dispose();
  }

  /// «شاهدته مؤخراً» من سجل الهاتف؛ قسم مساعد فلا نعرض خطأ إن فشل.
  Future<void> _loadRecent() async {
    try {
      final ids = await RecentlyViewedStore.ids();
      final products = ids.isEmpty
          ? <Product>[]
          : await _productService.byIds(ids.take(10).toList());
      if (mounted) setState(() => _recentProducts = products);
    } catch (e) {
      debugPrint('recently viewed load failed: $e');
    }
  }

  Future<void> _load() async {
    await Future.wait([
      _loadProducts(),
      _loadCategories(),
      _loadStories(),
      _loadDailyDeals(),
      _loadShowcases(),
      _loadRecent(),
    ]);
  }

  /// مساحات العرض المؤجّرة؛ قسم إعلاني اختياري فلا نعرض خطأ إن فشل تحميله.
  Future<void> _loadShowcases() async {
    try {
      final showcases = await _showcaseService.homeShowcases();
      if (mounted) setState(() => _showcases = showcases);
    } catch (e) {
      debugPrint('showcases load failed: $e');
    }
  }

  /// تجلب عروض اليوم الفعلية (daily_deals) من الـ API.
  Future<void> _loadDailyDeals() async {
    if (mounted) {
      setState(() {
        _dailyDealsLoading = true;
        _dailyDealsError = null;
      });
    }
    try {
      final deals = await _productService.dailyDeals();
      if (mounted) {
        setState(() {
          _dailyDealProducts = deals;
          _dailyDealsLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _dailyDealProducts = const [];
          _dailyDealsLoading = false;
          final msg = e.toString().replaceFirst('ApiException: ', '').trim();
          _dailyDealsError = msg.isNotEmpty
              ? 'تعذر تحميل عروض اليوم: $msg\n${ApiConfig.baseUrl}/daily-deal'
              : 'تعذر تحميل عروض اليوم حالياً.\n${ApiConfig.baseUrl}/daily-deal';
        });
      }
      debugPrint(
          'daily-deals load failed: $e url=${ApiConfig.baseUrl}/daily-deal');
    }
  }

  Future<void> _loadProducts() async {
    if (mounted) setState(() => _productsError = null);
    try {
      final products = await _productService.list(sort: 'newest');
      if (!mounted) return;
      setState(() {
        _products = products;
        _favoriteIds
          ..clear()
          ..addAll(products
              .where((product) => product.isFavorited)
              .map((p) => p.id));
      });
    } on ApiException catch (error) {
      if (mounted) setState(() => _productsError = error.message);
    } catch (_) {
      if (mounted) setState(() => _productsError = 'فشل تحميل المنتجات.');
    }
  }

  Future<void> _loadCategories() async {
    if (mounted) setState(() => _categoriesError = null);
    try {
      final categories = await _categoryService.list();
      if (mounted) setState(() => _categories = categories);
    } on ApiException catch (error) {
      if (mounted) setState(() => _categoriesError = error.message);
    } catch (_) {
      if (mounted) setState(() => _categoriesError = 'تعذّر تحميل الأقسام.');
    }
  }

  Future<void> _loadStories() async {
    try {
      final stories = await _storyService.getActiveStories();
      if (mounted) setState(() => _stories = stories);
    } catch (_) {
      if (mounted) setState(() => _stories = const []);
    }
  }

  void _openSearch() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SearchScreen()));
  }

  void _openDeals() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => SearchScreen(
          initialOnSale: true,
          productService: _productService,
          categoryService: _categoryService,
        ),
      ),
    );
  }

  void _openProduct(Product product) {
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(slug: product.slug),
      ),
    );
  }

  void _openCategory(Category category) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CategoryProductsScreen(
          slug: category.slug,
          name: category.name,
          children: category.children,
          categoryService: _categoryService,
        ),
      ),
    );
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

    final wasFavorite = _favoriteIds.contains(product.id);
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(product.id);
      } else {
        _favoriteIds.add(product.id);
      }
    });

    try {
      final isFavorite = await _favoriteService.toggle(product.id);
      if (mounted) {
        setState(() {
          if (isFavorite) {
            _favoriteIds.add(product.id);
          } else {
            _favoriteIds.remove(product.id);
          }
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        if (wasFavorite) {
          _favoriteIds.add(product.id);
        } else {
          _favoriteIds.remove(product.id);
        }
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تعذّر تحديث المفضلة. حاول مجدداً.')),
      );
    }
  }

  /// دالة مساعدة لصيغة عروض اليوم باللغة العربية
  String _formatOfferCount(int count) {
    if (count == 0) return 'لا توجد عروض';
    if (count == 1) return 'عرض واحد';
    if (count == 2) return 'عرضان';
    if (count >= 3 && count <= 10) return '$count عروض';
    return '$count عرضاً';
  }

  /// نفس خريطة أيقونات شريط الأقسام في الويب وبالترتيب نفسه؛ null => يُعرض أول حرف.
  static const _categoryIcons = <String, IconData>{
    'إلكترون': Icons.smartphone_rounded,
    'رجالية': Icons.man_rounded,
    'نسائية': Icons.woman_rounded,
    'المطبخ': Icons.coffee_rounded,
    'الجمال': Icons.auto_awesome_rounded,
    'الأطفال': Icons.child_care_rounded,
    'الغذائية': Icons.shopping_basket_rounded,
    'الرياضة': Icons.pedal_bike_rounded,
    'الكتب': Icons.menu_book_rounded,
    'السيارات': Icons.directions_car_rounded,
    'الأحذية': Icons.shopping_bag_rounded,
    'الساعات': Icons.watch_rounded,
    'العطور': Icons.water_drop_rounded,
    'الأثاث': Icons.chair_rounded,
    'الحرف': Icons.palette_rounded,
    'الهدايا': Icons.card_giftcard_rounded,
    'الحيوانات': Icons.pets_rounded,
    'الحدائق': Icons.local_florist_rounded,
    'الصحة': Icons.medication_rounded,
    'الأدوات': Icons.handyman_rounded,
  };

  IconData? _getCategoryIcon(String name) {
    for (final entry in _categoryIcons.entries) {
      if (name.contains(entry.key)) return entry.value;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brandGreen,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(child: _buildHeader()),
              SliverToBoxAdapter(child: _buildCategories()),
              if (_stories != null && _stories!.isNotEmpty)
                SliverToBoxAdapter(child: _buildStories()),
              if (_products != null && _products!.isNotEmpty)
                SliverToBoxAdapter(child: _buildSpotlight()),
              if (_hasDailyDealProducts ||
                  _dailyDealsLoading ||
                  _dailyDealsError != null)
                SliverToBoxAdapter(child: _buildDailyDealsSection()),
              if (_recentProducts.isNotEmpty)
                SliverToBoxAdapter(child: _buildRecentlyViewed()),
              for (final showcase in _showcases)
                SliverToBoxAdapter(
                  child: ShowcaseSection(
                    key: ValueKey('showcase-${showcase.id}'),
                    data: showcase,
                    onImpression: () =>
                        _showcaseService.track(showcase.id, 'impression'),
                    onProductTap: (product) {
                      _showcaseService.track(showcase.id, 'click');
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              ProductDetailScreen(slug: product.slug),
                        ),
                      );
                    },
                    onStoreTap: () {
                      _showcaseService.track(showcase.id, 'click');
                      Navigator.of(context, rootNavigator: true).push(
                        MaterialPageRoute(
                          builder: (_) =>
                              StoreScreen(storeId: showcase.storeId),
                        ),
                      );
                    },
                  ),
                ),
              SliverToBoxAdapter(child: _buildProductsHeading()),
              _buildProductGrid(),
              const SliverToBoxAdapter(child: SizedBox(height: 18)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        children: [
          Row(
            children: [
              // يصغر الشعار تلقائياً في الشاشات الضيقة بدل أن يتجاوز العرض
              const Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: AlignmentDirectional.centerStart,
                  child: BrandWordmark(),
                ),
              ),
              const Spacer(),
              _HeaderAction(
                icon: Icons.support_agent_rounded,
                label: 'خدمة العملاء',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ChatScreen()),
                ),
              ),
              const SizedBox(width: 4),
              _HeaderAction(
                icon: Icons.notifications_none_rounded,
                label: 'الإشعارات',
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const NotificationsScreen(),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Consumer<ThemeController>(
                builder: (context, themeController, _) {
                  return _HeaderAction(
                    icon: isDark
                        ? Icons.wb_sunny_rounded
                        : Icons.dark_mode_rounded,
                    label: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                    onTap: () {
                      themeController.toggleTheme();
                    },
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: _openSearch,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                height: 50,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: isDark
                      ? Theme.of(context).colorScheme.surface
                      : Colors.white,
                  border: Border.all(
                    color: AppColors.brandGreen.withValues(alpha: 0.2),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandGreen.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded,
                        color: AppColors.brandGreen, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AppText(
                        'ابحث عن منتج، متجر، أو قسم...',
                        style: TextStyle(
                          fontSize: 13,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    Icon(
                      Icons.tune_rounded,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withValues(alpha: .58),
                      size: 19,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategories() {
    if (_categoriesError != null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Row(
          children: [
            const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                _categoriesError!,
                maxLines: 2,
                style: const TextStyle(fontSize: 12),
              ),
            ),
            TextButton(
              onPressed: _loadCategories,
              child: const AppText('إعادة المحاولة'),
            ),
          ],
        ),
      );
    }
    if (_categories == null) {
      return const CategoryListSkeleton();
    }
    if (_categories!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(16, 2, 16, 12),
        child: AppText(
          'لا توجد أقسام متاحة حالياً.',
          style: TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      );
    }

    // فقاعات الأقسام كما في شريط الويب (partials/header: ts-catbub) بلا عنوان
    return SizedBox(
      height: 92,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 4),
        itemCount: _categories!.length,
        separatorBuilder: (_, __) => const SizedBox(width: 4),
        itemBuilder: (context, index) {
          final category = _categories![index];
          return _CategoryBubble(
            name: category.name,
            icon: _getCategoryIcon(category.name),
            variant: index % 3,
            onTap: () => _openCategory(category),
          );
        },
      ),
    );
  }

  Widget _buildStories() {
    final stories = _stories!;
    return SizedBox(
      height: 100,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
        scrollDirection: Axis.horizontal,
        itemCount: stories.length,
        separatorBuilder: (_, __) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final story = stories[index];
          return InkWell(
            onTap: () => _openStory(story),
            borderRadius: BorderRadius.circular(40),
            child: SizedBox(
              width: 66,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(2),
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [AppColors.brandGreen, AppColors.gold],
                      ),
                    ),
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        shape: BoxShape.circle,
                      ),
                      child: ClipOval(
                        child: SizedBox(
                          width: 50,
                          height: 50,
                          child: CachedNetworkImage(
                            imageUrl: story.imageUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(Icons.person, size: 24),
                            ),
                            placeholder: (_, __) => Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  AppText(
                    story.vendorName ?? 'قصة جديدة',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  void _openStory(StoryModel story) {
    final stories = _stories ?? const <StoryModel>[];
    final index = stories.indexWhere((item) => item.id == story.id);
    if (index < 0) return;
    showStoryViewer(context, stories: stories, initialIndex: index);
  }

  Widget _buildSpotlight() {
    final product = _deals.isNotEmpty ? _deals.first : _products!.first;
    final isDeal = _deals.isNotEmpty;
    final discount = product.displayDiscountPercentage;

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Material(
        color: AppColors.brandGreen,
        borderRadius: BorderRadius.circular(18),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _openProduct(product),
          child: SizedBox(
            height: 170,
            child: Stack(
              children: [
                const PositionedDirectional(
                  start: 0,
                  top: 0,
                  bottom: 0,
                  width: 5,
                  child: ColoredBox(color: AppColors.gold),
                ),
                PositionedDirectional(
                  end: 16,
                  top: 12,
                  bottom: 12,
                  width: 120,
                  child: product.primaryImage == null
                      ? Container(
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: .08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.shopping_bag_outlined,
                            color: Colors.white30,
                            size: 62,
                          ),
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.all(8),
                          child: CachedNetworkImage(
                            imageUrl: product.primaryImage!.url,
                            fit: BoxFit.contain,
                            placeholder: (_, __) => const Center(
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)),
                            errorWidget: (_, __, ___) => const Icon(
                              Icons.image_not_supported_outlined,
                              color: AppColors.muted,
                              size: 38,
                            ),
                          ),
                        ),
                ),
                Padding(
                  padding:
                      const EdgeInsetsDirectional.fromSTEB(16, 12, 150, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: isDeal
                                    ? AppColors.gold
                                    : Colors.white.withValues(alpha: .16),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                isDeal ? 'تخفيضات مختارة' : 'أحدث المنتجات',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: isDeal ? Colors.black : Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                          if (isDeal && discount != null) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.sale,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: AppText(
                                '-$discount%',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 6),
                      AppText(
                        product.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.25,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Flexible(
                            child: AppText(
                              product.formattedPrice,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.goldLight,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isDeal &&
                              product.formattedCompareAtPrice != null) ...[
                            const SizedBox(width: 8),
                            Flexible(
                              child: AppText(
                                product.formattedCompareAtPrice!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  color: Colors.white60,
                                  fontSize: 11,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppColors.gold,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: AppText(
                                'تسوّق الآن',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_rounded,
                                color: Colors.black, size: 14),
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
      ),
    );
  }

  Widget _buildDailyDealsSection() {
    final deals = _dailyDealProducts ?? const <Product>[];
    final firstEndsAt = deals.isNotEmpty ? deals.first.dealEndsAt : null;
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      child: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: AppColors.brandGreen.withValues(alpha: 0.15), width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.brandGreen.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [AppColors.brandGreen, AppColors.brandGreenLight],
                  begin: Alignment.centerRight,
                  end: Alignment.centerLeft,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(15)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.flash_on, color: AppColors.gold, size: 18),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: AppText(
                      'عروض اليوم المميزة',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  if (firstEndsAt != null)
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: AppText(
                          'ينتهي ${_formatDealEnds(firstEndsAt)}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  if (deals.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: AppText(
                        _formatOfferCount(deals.length),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: AppColors.goldLight,
                            fontSize: 12,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: _openDeals,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const AppText(
                          'كل المنتجات',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        Icon(
                          Directionality.of(context) == TextDirection.rtl
                              ? Icons.chevron_left
                              : Icons.chevron_right,
                          color: Colors.white,
                          size: 16,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (_dailyDealsLoading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Center(
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.4, color: AppColors.brandGreen),
                  ),
                ),
              )
            else if (_dailyDealsError != null)
              Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    Expanded(
                      child: AppText(
                        _dailyDealsError!,
                        style: const TextStyle(
                            color: AppColors.danger, fontSize: 13),
                      ),
                    ),
                    TextButton(
                      onPressed: _loadDailyDeals,
                      child: const AppText('إعادة المحاولة'),
                    ),
                  ],
                ),
              )
            else if (deals.isEmpty)
              Padding(
                padding: const EdgeInsets.all(14),
                child: AppText(
                  'لا توجد عروض يومية نشطة حالياً.',
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13),
                ),
              )
            else
              SizedBox(
                height: 292,
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 14),
                  scrollDirection: Axis.horizontal,
                  itemCount: deals.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 10),
                  itemBuilder: (context, index) => SizedBox(
                    width: 154,
                    child: _productCard(deals[index]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  String _formatDealEnds(DateTime endsAt) {
    final local = endsAt.toLocal();
    final diff = local.difference(DateTime.now());
    if (diff.isNegative) return 'قريباً';
    if (diff.inDays >= 1) return 'خلال ${diff.inDays} يوم';
    if (diff.inHours >= 1) return 'خلال ${diff.inHours} س';
    return 'خلال ${diff.inMinutes.clamp(1, 59)} د';
  }

  Widget _buildRecentlyViewed() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Padding(
          padding: EdgeInsets.only(top: 8),
          child: _SectionHeading(
            title: 'شاهدته مؤخراً',
            icon: Icons.history_rounded,
            actionLabel: 'مسح السجل',
            onAction: RecentlyViewedStore.clear,
          ),
        ),
        SizedBox(
          height: 292,
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
            scrollDirection: Axis.horizontal,
            itemCount: _recentProducts.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) => SizedBox(
              width: 154,
              child: _productCard(_recentProducts[index]),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProductsHeading() {
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 4),
      child: _SectionHeading(
        title: 'أحدث المنتجات',
        icon: Icons.auto_awesome_outlined,
        actionLabel: 'تصفّح الكل',
        onAction: _openSearch,
      ),
    );
  }

  Widget _buildProductGrid() {
    if (_productsError != null) {
      return SliverFillRemaining(
        hasScrollBody: false,
        child: AppStateMessage(
          message: _productsError!,
          icon: Icons.error_outline,
          onRetry: _loadProducts,
        ),
      );
    }
    if (_products == null) {
      return const SliverToBoxAdapter(
        child: ProductGridSkeleton(itemCount: 4),
      );
    }
    if (_products!.isEmpty) {
      return const SliverFillRemaining(
        hasScrollBody: false,
        child: AppStateMessage(
          message: 'لا توجد منتجات متاحة حالياً.',
          icon: Icons.inventory_2_outlined,
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 8),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.66,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) => _productCard(_products![index]),
          childCount: _products!.length,
        ),
      ),
    );
  }

  Widget _productCard(Product product) {
    return _PressedScale(
      child: ProductCard(
        product: product,
        isFavorited: _favoriteIds.contains(product.id),
        onFavoriteTap: () => _toggleFavorite(product),
        onImageLongPress: () => _showQuickView(product),
        onAddToCart: (sourceContext, imageUrl,
                {specialPrice, discountPercentage}) =>
            AddToCartFly.add(
          context,
          productId: product.id,
          sourceContext: sourceContext,
          imageUrl: imageUrl,
          specialPrice: specialPrice,
          discountPercentage: discountPercentage,
        ),
        onTap: () => _openProduct(product),
        openBuilder: (_) => ProductDetailScreen(
          slug: product.slug,
          initialProduct: product,
        ),
      ),
    );
  }

  void _showQuickView(Product product) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => QuickViewBottomSheet(product: product),
    );
  }
}
