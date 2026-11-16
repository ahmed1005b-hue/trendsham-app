import 'dart:async';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/product_service.dart';
import '../../services/api_exception.dart';
import '../../services/api_client.dart';
import '../../services/search_history_service.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/shimmer_loading.dart';
import '../product/product_detail_screen.dart';
import '../store/store_screen.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({
    super.key,
    this.initialOnSale = false,
    this.productService,
    this.categoryService,
  });

  final bool initialOnSale;
  final ProductService? productService;
  final CategoryService? categoryService;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final ProductService _productService =
      widget.productService ?? ProductService();
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;

  List<Product>? _results;
  int _currentPage = 1;
  int _lastPage = 1;
  // كل بحث يأخذ رقماً؛ الردود المتأخرة لبحث قديم تُهمل
  int _searchSeq = 0;
  final _scroll = ScrollController();
  bool _isLoading = false;
  bool _loadingMore = false;
  String? _error;
  SearchSuggestions? _suggestions;

  // ===== الفلاتر =====
  String? _sort; // newest | price_asc | price_desc | rating
  double? _minPrice;
  double? _maxPrice;
  String? _categorySlug;
  bool _inStock = false;
  bool _onSale = false;
  double? _minRating;
  int _activeFilterCount = 0;

  // الأقسام المتاحة من الخادم
  List<SuggestionCategory> _categories = [];
  List<String> _recentSearches = [];
  // تُستبدل بقائمة السيرفر عند وصولها؛ القائمة المحلية احتياط عند انقطاع الاتصال
  List<String> _trending = SearchHistoryService.popularSearches;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _loadRecentSearches();
    _loadTrending();
    if (widget.initialOnSale) {
      _onSale = true;
      _activeFilterCount = 1;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _runSearch();
      });
    }
  }

  Future<void> _loadRecentSearches() async {
    final list = await SearchHistoryService.getRecentSearches();
    if (mounted) setState(() => _recentSearches = list);
  }

  Future<void> _loadTrending() async {
    try {
      final list = await _productService.trending();
      if (mounted && list.isNotEmpty) setState(() => _trending = list);
    } catch (_) {}
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String _t(String key) => AppLocalizations.of(context).translate(key);

  bool get _hasFilters =>
      _sort != null ||
      _minPrice != null ||
      _maxPrice != null ||
      _categorySlug != null ||
      _inStock ||
      _onSale ||
      _minRating != null;

  void _runSearch({bool loadMore = false}) {
    final query = _controller.text.trim();
    if (query.isNotEmpty && !loadMore) {
      SearchHistoryService.addQuery(query);
      _loadRecentSearches();
    }
    if (query.isEmpty && !_hasFilters) {
      setState(() {
        _results = null;
        _suggestions = null;
      });
      return;
    }
    if (loadMore) {
      if (_currentPage >= _lastPage) return;
      setState(() => _loadingMore = true);
    } else {
      setState(() {
        _isLoading = true;
        _error = null;
        if (!_hasFilters) _suggestions = null;
      });
    }
    final page = loadMore ? _currentPage + 1 : 1;
    final seq = loadMore ? _searchSeq : ++_searchSeq;
    bool stale() => !mounted || seq != _searchSeq;
    _productService
        .search(query,
            sort: _sort,
            minPrice: _minPrice,
            maxPrice: _maxPrice,
            categorySlug: _categorySlug,
            inStock: _inStock,
            onSale: _onSale,
            minRating: _minRating,
            page: page)
        .then((result) {
      if (stale()) return;
      setState(() {
        if (loadMore && _results != null) {
          _results = [..._results!, ...result.products];
        } else {
          _results = result.products;
        }
        _currentPage = result.currentPage;
        _lastPage = result.lastPage;
      });
      if (!loadMore && _scroll.hasClients) _scroll.jumpTo(0);
    }).onError<ApiException>((e, _) {
      if (stale()) return;
      if (!loadMore) {
        setState(() {
          _error = e.message;
          _results = null;
        });
      }
    }).catchError((_) {
      if (stale()) return;
      if (!loadMore) {
        setState(() {
          _error = _t('تعذر البحث.');
          _results = null;
        });
      }
    }).whenComplete(() {
      if (stale()) return;
      setState(() {
        _isLoading = false;
        _loadingMore = false;
      });
    });
  }

  void _onQueryChanged(String value) {
    _debounce?.cancel();
    if (value.trim().isEmpty) {
      setState(() => _suggestions = null);
      return;
    }
    // اقتراحات فورية بعد 300ms من توقف الكتابة
    _debounce = Timer(const Duration(milliseconds: 300), () async {
      try {
        final s = await _productService.suggestions(value.trim());
        if (mounted && _controller.text.trim() == value.trim()) {
          setState(() => _suggestions = s);
        }
      } catch (_) {
        // الاقتراحات ميزة إضافية، نتجاهل أخطاءها بصمت
      }
    });
  }

  Future<void> _openFilterSheet() async {
    final applied = await showModalBottomSheet<_FilterResult>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _FilterSheet(
        initialSort: _sort,
        initialMinPrice: _minPrice,
        initialMaxPrice: _maxPrice,
        initialCategorySlug: _categorySlug,
        initialInStock: _inStock,
        initialOnSale: _onSale,
        initialMinRating: _minRating,
        categories: _categories,
        t: _t,
      ),
    );
    if (applied != null) {
      setState(() {
        _sort = applied.sort;
        _minPrice = applied.minPrice;
        _maxPrice = applied.maxPrice;
        _categorySlug = applied.categorySlug;
        _inStock = applied.inStock;
        _onSale = applied.onSale;
        _minRating = applied.minRating;
        _activeFilterCount = applied.count;
      });
      _runSearch();
    }
  }

  void _clearFilters() {
    setState(() {
      _sort = null;
      _minPrice = null;
      _maxPrice = null;
      _categorySlug = null;
      _inStock = false;
      _onSale = false;
      _minRating = null;
      _activeFilterCount = 0;
    });
    _runSearch();
  }

  void _loadCategories() {
    // نجلب الأقسام من خدمة الأقسام العامة عبر اقتراح فارغ
    // (suggestions يعيد قوائم فارغة عند q فارغ لكن الأقسام نجلبها من CategoryService)
    // نستخدم فلتر الأقسام عبر الـ bottom sheet بعد جلبها مرة واحدة.
    if (widget.categoryService == null) {
      CategoryLoader.fetch().then((list) {
        if (mounted) setState(() => _categories = list);
      });
      return;
    }

    widget.categoryService!.list().then((items) {
      if (mounted) {
        setState(
          () => _categories = items
              .map((item) =>
                  SuggestionCategory(slug: item.slug, name: item.name))
              .toList(),
        );
      }
    }).catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    _loadCategoriesOnce();
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focusNode,
                autofocus: !widget.initialOnSale,
                textInputAction: TextInputAction.search,
                style: TextStyle(
                    fontSize: 15,
                    color: Theme.of(context).colorScheme.onSurface),
                cursorColor: context.accent,
                onChanged: _onQueryChanged,
                onSubmitted: (_) {
                  _debounce?.cancel();
                  setState(() => _suggestions = null);
                  _runSearch();
                },
                decoration: InputDecoration(
                  hintText: _t('ابحث عن منتج...'),
                  hintStyle: TextStyle(color: context.mutedText, fontSize: 14),
                  prefixIcon: Icon(Icons.search,
                      color: context.mutedText, size: 22),
                  suffixIcon: _controller.text.isNotEmpty
                      ? IconButton(
                          tooltip: context.tr('مسح البحث'),
                          icon: Icon(Icons.close,
                              color: context.mutedText, size: 20),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _results = null;
                              _suggestions = null;
                            });
                            _focusNode.requestFocus();
                          },
                        )
                      : null,
                  filled: true,
                  // ليلاً: سطح داكن داخل الشريط الأخضر؛ نهاراً: كريمي بحدّ واضح على الأبيض
                  fillColor: context.isDarkTheme
                      ? Theme.of(context).colorScheme.surface
                      : AppColors.bgLight,
                  contentPadding: const EdgeInsets.symmetric(vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: context.softBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: context.isDarkTheme
                            ? Colors.transparent
                            : AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(
                        color: context.isDarkTheme
                            ? AppColors.gold
                            : AppColors.primary,
                        width: 1.3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // زر الفلاتر مع عدّاد
            Padding(
              padding: const EdgeInsetsDirectional.only(end: 8),
              child: Badge(
                isLabelVisible: _activeFilterCount > 0,
                label: AppText('$_activeFilterCount'),
                backgroundColor:
                    context.isDarkTheme ? AppColors.gold : AppColors.primary,
                textColor: context.isDarkTheme ? Colors.black : Colors.white,
                child: IconButton(
                  tooltip: context.tr('الفلاتر'),
                  icon: Icon(
                    Icons.tune,
                    // لون أيقونات الشريط (داكن نهاراً، أبيض على الأخضر ليلاً)
                    color: _activeFilterCount > 0
                        ? (context.isDarkTheme
                            ? AppColors.gold
                            : AppColors.primary)
                        : Theme.of(context).appBarTheme.foregroundColor,
                  ),
                  onPressed: _openFilterSheet,
                ),
              ),
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  bool _categoriesLoaded = false;
  void _loadCategoriesOnce() {
    if (_categoriesLoaded) return;
    _categoriesLoaded = true;
    _loadCategories();
  }

  Widget _buildBody() {
    return Column(
      children: [
        _buildQuickFilterBar(),
        Expanded(child: _buildBodyContent()),
      ],
    );
  }

  Widget _buildBodyContent() {
    if (_isLoading) {
      return const SingleChildScrollView(
        child: ProductGridSkeleton(itemCount: 6),
      );
    }
    if (_error != null) {
      return AppStateMessage(message: _error!, icon: Icons.error_outline);
    }
    if (_results == null) {
      if (_suggestions != null && !_suggestions!.isEmpty) {
        return _buildSuggestions();
      }
      return _buildSmartSearchLanding();
    }
    if (_results!.isEmpty) {
      return AppStateMessage(
        message: _t('لا توجد نتائج مطابقة. جرّب كلمات أخرى أو عدّل الفلاتر.'),
        icon: Icons.search_off,
        onRetry: _hasFilters ? _clearFilters : null,
      );
    }
    return _buildResults();
  }

  Widget _buildQuickFilterBar() {
    return Container(
      height: 42,
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: context.cardSurface,
        border: Border(bottom: BorderSide(color: context.softBorder, width: 0.6)),
      ),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        children: [
          _filterPill(
            label: 'تنزيلات 🏷️',
            isActive: _onSale,
            onTap: () {
              setState(() => _onSale = !_onSale);
              _runSearch();
            },
          ),
          const SizedBox(width: 6),
          _filterPill(
            label: 'متوفر بالمخزون 📦',
            isActive: _inStock,
            onTap: () {
              setState(() => _inStock = !_inStock);
              _runSearch();
            },
          ),
          const SizedBox(width: 6),
          _filterPill(
            label: 'تقييم 4+ ⭐',
            isActive: _minRating != null && _minRating! >= 4.0,
            onTap: () {
              setState(() => _minRating = (_minRating == 4.0 ? null : 4.0));
              _runSearch();
            },
          ),
          const SizedBox(width: 6),
          _filterPill(
            label: 'الأقل سعراً ⬇️',
            isActive: _sort == 'price_asc',
            onTap: () {
              setState(
                  () => _sort = (_sort == 'price_asc' ? null : 'price_asc'));
              _runSearch();
            },
          ),
          const SizedBox(width: 6),
          _filterPill(
            label: 'الأعلى سعراً ⬆️',
            isActive: _sort == 'price_desc',
            onTap: () {
              setState(
                  () => _sort = (_sort == 'price_desc' ? null : 'price_desc'));
              _runSearch();
            },
          ),
        ],
      ),
    );
  }

  Widget _filterPill({
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 4),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primary : context.mutedSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? AppColors.primary : context.softBorder,
            width: 0.8,
          ),
        ),
        alignment: Alignment.center,
        child: AppText(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isActive ? FontWeight.bold : FontWeight.w500,
            color: isActive
                ? Colors.white
                : Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  }

  Widget _buildSmartSearchLanding() {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. سجل عمليات البحث الأخيرة
          if (_recentSearches.isNotEmpty) ...[
            Row(
              children: [
                Icon(Icons.history, size: 18, color: context.mutedText),
                const SizedBox(width: 6),
                AppText(
                  _t('عمليات البحث الأخيرة'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                InkWell(
                  onTap: () async {
                    await SearchHistoryService.clearHistory();
                    setState(() => _recentSearches = []);
                  },
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
                    child: AppText(
                      _t('مسح الكل'),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.danger),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _recentSearches.map((query) {
                return Chip(
                  label: AppText(query, style: const TextStyle(fontSize: 12)),
                  backgroundColor: context.mutedSurface,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.softBorder),
                  ),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () async {
                    await SearchHistoryService.removeQuery(query);
                    _loadRecentSearches();
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),
          ],

          // 2. الكلمات الأكثر بحثاً
          Row(
            children: [
              Icon(Icons.local_fire_department,
                  size: 18, color: context.accent),
              const SizedBox(width: 6),
              AppText(
                _t('الكلمات الأكثر بحثاً'),
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _trending.map((tag) {
              return ActionChip(
                avatar: Icon(Icons.trending_up,
                    size: 14, color: context.accent),
                label: AppText(
                  tag,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w500),
                ),
                backgroundColor: context.cardSurface,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: BorderSide(color: context.softBorder),
                ),
                onPressed: () {
                  _controller.text = tag;
                  _runSearch();
                },
              );
            }).toList(),
          ),

          // 3. تصفح حسب الأقسام
          if (_categories.isNotEmpty) ...[
            const SizedBox(height: 22),
            Row(
              children: [
                const Icon(Icons.category_outlined,
                    size: 18, color: AppColors.brandGreen),
                const SizedBox(width: 6),
                AppText(
                  _t('تصفح حسب الأقسام'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _categories.take(10).map((cat) {
                final isSelected = _categorySlug == cat.slug;
                return FilterChip(
                  label:
                      AppText(cat.name, style: const TextStyle(fontSize: 12)),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                      color: isSelected
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface),
                  backgroundColor: context.mutedSurface,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: context.softBorder),
                  ),
                  onSelected: (selected) {
                    setState(() {
                      _categorySlug = selected ? cat.slug : null;
                    });
                    _runSearch();
                  },
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildResults() {
    final total = _results!.length;
    return Column(
      children: [
        // شريط ملخص النتائج + زر مسح الفلاتر
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          color: context.mutedSurface,
          child: Row(
            children: [
              Expanded(
                child: AppText(
                  '$total ${total == 1 ? _t('نتيجة') : _t('نتائج')} · ${_t('نتائج البحث')}',
                  style: TextStyle(fontSize: 13, color: context.mutedText),
                ),
              ),
              if (_hasFilters)
                TextButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(Icons.filter_alt_off,
                      size: 16, color: context.accent),
                  label: AppText(_t('أمسح الفلاتر'),
                      style: TextStyle(
                          fontSize: 13, color: context.accent)),
                ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            controller: _scroll,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.62,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: _results!.length + (_loadingMore ? 2 : 0),
            itemBuilder: (context, index) {
              if (index >= _results!.length) {
                return Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: context.accent));
              }
              final product = _results![index];
              return ProductCard(
                product: product,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(slug: product.slug)),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// تحميل الصفحة التالية عند الاقتراب من نهاية النتائج (تصفح لا نهائي).
  void _onScroll() {
    if (_loadingMore || _isLoading || _results == null) return;
    if (_currentPage >= _lastPage || !_scroll.hasClients) return;
    if (_scroll.position.extentAfter < 600) _runSearch(loadMore: true);
  }

  Widget _buildSuggestions() {
    final s = _suggestions!;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (s.products.isNotEmpty) ...[
          _sectionHeader(_t('منتجات'), Icons.inventory_2_outlined),
          ...s.products.map((p) => _suggestionTile(
                leading: p.image != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(p.image!,
                            width: 44,
                            height: 44,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => SizedBox(
                                width: 44,
                                height: 44,
                                child: Icon(Icons.image_not_supported,
                                    color: context.mutedText))),
                      )
                    : Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: context.softTint(AppColors.gold),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(Icons.inventory_2_outlined,
                            color: context.accent, size: 22),
                      ),
                title: p.name ?? '',
                trailing: p.price != null
                    ? AppText('${p.price!.toStringAsFixed(0)} ل.س',
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: context.accent))
                    : null,
                onTap: () {
                  if (p.slug != null) {
                    setState(() => _suggestions = null);
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => ProductDetailScreen(slug: p.slug!)));
                  }
                },
              )),
        ],
        if (s.categories.isNotEmpty) ...[
          _sectionHeader(_t('أقسام'), Icons.category_outlined),
          ...s.categories.map((c) => _suggestionTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.softTint(AppColors.gold),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.category_outlined,
                      color: context.accent, size: 22),
                ),
                title: c.name ?? '',
                onTap: () {
                  if (c.slug != null) {
                    _debounce?.cancel();
                    _controller.text = c.name ?? '';
                    setState(() {
                      _categorySlug = c.slug;
                      _suggestions = null;
                    });
                    _runSearch();
                  }
                },
              )),
        ],
        if (s.stores.isNotEmpty) ...[
          _sectionHeader(_t('متاجر'), Icons.storefront),
          ...s.stores.map((st) => _suggestionTile(
                leading: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: context.softTint(AppColors.gold),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.storefront,
                      color: context.accent, size: 22),
                ),
                title: st.name ?? '',
                onTap: () {
                  _debounce?.cancel();
                  if (st.storeId != null) {
                    Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) => StoreScreen(storeId: st.storeId!)));
                    return;
                  }
                  _controller.text = st.name ?? '';
                  setState(() => _suggestions = null);
                  _runSearch();
                },
              )),
        ],
      ],
    );
  }

  Widget _sectionHeader(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6),
      child: Row(
        children: [
          Icon(icon, size: 18, color: context.accent),
          const SizedBox(width: 6),
          AppText(title,
              style:
                  const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _suggestionTile({
    required Widget leading,
    required String title,
    Widget? trailing,
    required VoidCallback onTap,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: leading,
      title: AppText(title, style: const TextStyle(fontSize: 14)),
      trailing: trailing,
      onTap: onTap,
    );
  }
}

// ===== نتيجة الفلاتر المطبقة =====
class _FilterResult {
  final String? sort;
  final double? minPrice;
  final double? maxPrice;
  final String? categorySlug;
  final bool inStock;
  final bool onSale;
  final double? minRating;
  const _FilterResult({
    this.sort,
    this.minPrice,
    this.maxPrice,
    this.categorySlug,
    this.inStock = false,
    this.onSale = false,
    this.minRating,
  });
  int get count =>
      (sort != null ? 1 : 0) +
      (minPrice != null || maxPrice != null ? 1 : 0) +
      (categorySlug != null ? 1 : 0) +
      (inStock ? 1 : 0) +
      (onSale ? 1 : 0) +
      (minRating != null ? 1 : 0);
}

// ===== Bottom Sheet الفلاتر =====
class _FilterSheet extends StatefulWidget {
  final String? initialSort;
  final double? initialMinPrice;
  final double? initialMaxPrice;
  final String? initialCategorySlug;
  final bool initialInStock;
  final bool initialOnSale;
  final double? initialMinRating;
  final List<SuggestionCategory> categories;
  final String Function(String) t;
  const _FilterSheet({
    required this.initialSort,
    required this.initialMinPrice,
    required this.initialMaxPrice,
    required this.initialCategorySlug,
    required this.initialInStock,
    required this.initialOnSale,
    required this.initialMinRating,
    required this.categories,
    required this.t,
  });
  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late String? _sort = widget.initialSort;
  late double? _minPrice = widget.initialMinPrice;
  late double? _maxPrice = widget.initialMaxPrice;
  late String? _categorySlug = widget.initialCategorySlug;
  late bool _inStock = widget.initialInStock;
  late bool _onSale = widget.initialOnSale;
  late double? _minRating = widget.initialMinRating;

  static const _sortOptions = [
    ('newest', 'الأحدث'),
    ('price_asc', 'الأقل سعراً'),
    ('price_desc', 'الأعلى سعراً'),
    ('rating', 'الأعلى تقييماً'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // العنوان
            Row(
              children: [
                Icon(Icons.tune, color: context.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: AppText(widget.t('فلاتر'),
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.bold)),
                ),
                TextButton(
                  onPressed: () {
                    setState(() {
                      _sort = null;
                      _minPrice = null;
                      _maxPrice = null;
                      _categorySlug = null;
                      _inStock = false;
                      _onSale = false;
                      _minRating = null;
                    });
                  },
                  child: AppText(widget.t('إعادة تعيين'),
                      style: TextStyle(
                          fontSize: 13, color: context.accent)),
                ),
              ],
            ),
            const Divider(),

            // الترتيب
            AppText(widget.t('الترتيب'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: _sortOptions
                  .map((option) => ChoiceChip(
                        label: AppText(widget.t(option.$2)),
                        selected: _sort == option.$1,
                        selectedColor: context.softTint(AppColors.gold),
                        labelStyle: TextStyle(
                          color: _sort == option.$1
                              ? context.goldText
                              : Theme.of(context).colorScheme.onSurface,
                          fontWeight: _sort == option.$1
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                        onSelected: (_) => setState(() {
                          _sort = _sort == option.$1 ? null : option.$1;
                        }),
                      ))
                  .toList(),
            ),
            const SizedBox(height: 16),

            // نطاق السعر
            AppText(widget.t('نطاق السعر'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: widget.t('من'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => _minPrice = double.tryParse(v.trim()),
                  ),
                ),
                const SizedBox(width: 8),
                const AppText('—'),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      hintText: widget.t('إلى'),
                      isDense: true,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onChanged: (v) => _maxPrice = double.tryParse(v.trim()),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // القسم
            AppText(widget.t('القسم'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: AppText(widget.t('الكل')),
                  selected: _categorySlug == null,
                  selectedColor: context.softTint(AppColors.gold),
                  onSelected: (_) => setState(() => _categorySlug = null),
                ),
                ...widget.categories.map(
                  (c) => ChoiceChip(
                    label: AppText(c.name),
                    selected: _categorySlug == c.slug,
                    selectedColor: context.softTint(AppColors.gold),
                    onSelected: (_) => setState(() {
                      _categorySlug = _categorySlug == c.slug ? null : c.slug;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // خيارات سريعة
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(widget.t('متوفر فقط'),
                  style: const TextStyle(fontSize: 14)),
              value: _inStock,
              activeThumbColor: context.accent,
              onChanged: (v) => setState(() => _inStock = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: AppText(widget.t('منتجات عليها خصم'),
                  style: const TextStyle(fontSize: 14)),
              value: _onSale,
              activeThumbColor: context.accent,
              onChanged: (v) => setState(() => _onSale = v),
            ),

            // التقييم
            AppText(widget.t('تقييم'),
                style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: AppText(widget.t('الكل')),
                  selected: _minRating == null,
                  selectedColor: context.softTint(AppColors.gold),
                  onSelected: (_) => setState(() => _minRating = null),
                ),
                ...[3.0, 4.0].map(
                  (r) => ChoiceChip(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star,
                            size: 16, color: AppColors.ratingStar),
                        const SizedBox(width: 4),
                        AppText(
                            '${widget.t('أعلى من')} ${r.toStringAsFixed(0)}'),
                      ],
                    ),
                    selected: _minRating == r,
                    selectedColor: context.softTint(AppColors.gold),
                    onSelected: (_) => setState(() {
                      _minRating = _minRating == r ? null : r;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // زر التطبيق
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  Navigator.of(context).pop(_FilterResult(
                    sort: _sort,
                    minPrice: _minPrice,
                    maxPrice: _maxPrice,
                    categorySlug: _categorySlug,
                    inStock: _inStock,
                    onSale: _onSale,
                    minRating: _minRating,
                  ));
                },
                child: AppText(widget.t('تطبيق الفلاتر'),
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===== أدوات مساعدة =====
class SuggestionCategory {
  final String slug;
  final String name;
  const SuggestionCategory({required this.slug, required this.name});
}

class CategoryLoader {
  static Future<List<SuggestionCategory>> fetch() async {
    try {
      final response = await ApiClient().get('/categories', withAuth: false);
      final data = response['data'] as List?;
      if (data == null) return const [];
      return data
          .whereType<Map>()
          .map((row) => SuggestionCategory(
              slug: row['slug'] as String? ?? '',
              name: row['name'] as String? ?? ''))
          .where((c) => c.slug.isNotEmpty)
          .toList();
    } catch (_) {
      return const [];
    }
  }
}

class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});
  @override
  Widget build(BuildContext context) {
    return Center(
        child: CircularProgressIndicator(color: context.accent));
  }
}
