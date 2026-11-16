import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/category.dart';
import '../../services/product_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import 'category_products_screen.dart';

class CategoriesTab extends StatefulWidget {
  const CategoriesTab({super.key});

  @override
  State<CategoriesTab> createState() => _CategoriesTabState();
}

class _CategoriesTabState extends State<CategoriesTab> {
  final CategoryService _categoryService = CategoryService();
  List<Category>? _categories;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final categories = await _categoryService.list();
      setState(() => _categories = categories);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الأقسام.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('الأقسام')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_categories == null) {
      return const LoadingIndicator();
    }
    if (_categories!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد أقسام مضافة بعد.', icon: Icons.category_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _categories!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final category = _categories![index];
        return Card(
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.surfaceContainerHighest,
              child: const Icon(Icons.grid_view, color: AppColors.emerald),
            ),
            title: AppText(category.name),
            trailing: const Icon(Icons.chevron_left),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => CategoryProductsScreen(
                  slug: category.slug,
                  name: category.name,
                  children: category.children,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
