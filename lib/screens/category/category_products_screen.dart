import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../l10n/category_translations.dart';
import '../../models/category.dart';
import '../../models/product.dart';
import '../../services/api_exception.dart';
import '../../services/product_service.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/product_card.dart';
import '../../widgets/shimmer_loading.dart';
import '../product/product_detail_screen.dart';

class CategoryProductsScreen extends StatefulWidget {
  final String slug;
  final String name;
  final List<Category> children;
  final CategoryService? categoryService;

  const CategoryProductsScreen({
    super.key,
    required this.slug,
    required this.name,
    this.children = const [],
    this.categoryService,
  });

  @override
  State<CategoryProductsScreen> createState() => _CategoryProductsScreenState();
}

class _CategoryProductsScreenState extends State<CategoryProductsScreen> {
  late final CategoryService _categoryService =
      widget.categoryService ?? CategoryService();
  List<Product>? _products;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final products = await _categoryService.products(widget.slug);
      setState(() => _products = products);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل المنتجات.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: AppText(CategoryTranslations.translate(
              widget.name, Localizations.localeOf(context)))),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_products == null) {
      return const SingleChildScrollView(
        child: ProductGridSkeleton(itemCount: 6),
      );
    }
    if (_products!.isEmpty && widget.children.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد منتجات بهذا القسم حالياً.',
          icon: Icons.inventory_2_outlined);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.children.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: AppText(
              'تصفح الأقسام الفرعية',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          SizedBox(
            height: 48,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              scrollDirection: Axis.horizontal,
              itemCount: widget.children.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final child = widget.children[index];
                return ActionChip(
                  label: AppText(CategoryTranslations.translate(
                      child.name, Localizations.localeOf(context))),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => CategoryProductsScreen(
                        slug: child.slug,
                        name: child.name,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
        if (_products!.isEmpty)
          const Expanded(
            child: AppStateMessage(
              message: 'لا يوجد منتجات بهذا القسم حالياً.',
              icon: Icons.inventory_2_outlined,
            ),
          )
        else
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(12),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                childAspectRatio: 0.62,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
              ),
              itemCount: _products!.length,
              itemBuilder: (context, index) {
                final product = _products![index];
                return ProductCard(
                  product: product,
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductDetailScreen(slug: product.slug),
                    ),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}
