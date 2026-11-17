import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import 'seller_product_form_screen.dart';

class SellerProductsScreen extends StatefulWidget {
  const SellerProductsScreen({super.key});

  @override
  State<SellerProductsScreen> createState() => _SellerProductsScreenState();
}

class _SellerProductsScreenState extends State<SellerProductsScreen> {
  final SellerService _service = SellerService();
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
      final products = await _service.products();
      setState(() => _products = products);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل منتجاتك.');
    }
  }

  Future<void> _delete(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الحذف'),
        content: AppText('حذف "${product.name}" نهائياً؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _service.deleteProduct(product.id);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('منتجاتي'),
        actions: [
          IconButton(
            tooltip: context.tr('إضافة منتج'),
            icon: const Icon(Icons.add),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(
                    builder: (_) => const SellerProductFormScreen()),
              );
              if (created == true) _load();
            },
          ),
        ],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_products == null) {
      return const LoadingIndicator();
    }
    if (_products!.isEmpty) {
      return const AppStateMessage(
          message: 'لسا ما أضفت أي منتج.', icon: Icons.inventory_2_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _products!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = _products![index];
        return Card(
          child: ListTile(
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Container(
                width: 48,
                height: 48,
                color: Theme.of(context)
                    .colorScheme
                    .surfaceContainerHighest
                    .withValues(alpha: 0.4),
                child: product.primaryImage != null
                    ? CachedNetworkImage(
                        imageUrl: product.primaryImage!.url,
                        fit: BoxFit.contain,
                        alignment: Alignment.center,
                      )
                    : Container(
                        color: Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                        child:
                            const Icon(Icons.inventory_2_outlined, size: 20)),
              ),
            ),
            title: AppText(product.name,
                maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(
                    '${product.formattedPrice} • مخزون: ${product.stockQuantity}'),
                _statusLine(product),
              ],
            ),
            onTap: () => _openEdit(product),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: context.tr('تعديل'),
                  icon:
                      const Icon(Icons.edit_outlined, color: AppColors.emerald),
                  onPressed: () => _openEdit(product),
                ),
                IconButton(
                  tooltip: context.tr('حذف'),
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _delete(product),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// حالة المنتج وسببها: مسودة، غير نشط، بانتظار المراجعة، أو مرفوض مع السبب
  Widget _statusLine(Product product) {
    final (String text, Color color) = product.rejectionNote != null
        ? ('مرفوض: ${product.rejectionNote}', AppColors.danger)
        : switch (product.status) {
            'draft' => ('مسودة - لا يظهر للزبائن', AppColors.muted),
            'inactive' => ('غير نشط - لا يظهر للزبائن', AppColors.muted),
            'active' when product.adminApproved == false => (
                'بانتظار موافقة الإدارة',
                const Color(0xFF9A7425)
              ),
            _ => ('ظاهر للزبائن', AppColors.emerald),
          };
    return AppText(text,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600));
  }

  Future<void> _openEdit(Product product) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
          builder: (_) => SellerProductFormScreen(product: product)),
    );
    if (updated == true) _load();
  }
}
