import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/profile_and_notifications_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/product_card.dart';
import '../../widgets/app_state_message.dart';
import '../product/product_detail_screen.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final FavoriteService _favoriteService = FavoriteService();
  List<Product>? _favorites;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final favorites = await _favoriteService.list();
      if (!mounted) return;
      setState(() => _favorites = favorites);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تحميل المفضلة.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('المفضلة')),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_favorites == null) {
      return const LoadingIndicator();
    }
    if (_favorites!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد منتجات مفضّلة بعد.', icon: Icons.favorite_border);
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: _favorites!.length,
      itemBuilder: (context, index) {
        final product = _favorites![index];
        return ProductCard(
          product: product,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
                builder: (_) => ProductDetailScreen(slug: product.slug)),
          ),
        );
      },
    );
  }
}
