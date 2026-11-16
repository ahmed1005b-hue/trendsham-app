import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../config/theme.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// شاشة إدارة المخزون الذكية: تنبيه للمنتجات قليلة الكمية + إدخال كمية سريع (+/-)
class SellerStockScreen extends StatefulWidget {
  const SellerStockScreen({super.key});
  @override
  State<SellerStockScreen> createState() => _SellerStockScreenState();
}

class _SellerStockScreenState extends State<SellerStockScreen> {
  final SellerService _service = SellerService();
  List<Map<String, dynamic>> _lowStock = [];
  bool _isLoading = true;
  final bool _loadingAll = false;
  String? _error;
  // قائمة المنتجات قليلة المخزون فقط من الخادم (التنبيه) — الإدخال السريع عبر نفس endpoint
  final Set<int> _busyProducts = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final products = await _service.lowStockProducts();
      setState(() => _lowStock = products);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل المخزون.');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _quickStock(Map<String, dynamic> product, int change) async {
    final id = (product['id'] as num?)?.toInt();
    if (id == null) return;
    setState(() => _busyProducts.add(id));
    try {
      await _service.quickStock(id, change: change);
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: AppText(
            change > 0
                ? 'تمت إضافة $change للكمية ✅'
                : 'تم خصم ${-change} من الكمية ✅',
          ),
          backgroundColor: AppColors.emerald,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('تعذّر تحديث الكمية.')));
    } finally {
      setState(() => _busyProducts.remove(id));
    }
  }

  Future<void> _setExact(Map<String, dynamic> product) async {
    final id = (product['id'] as num?)?.toInt();
    if (id == null) return;
    final controller = TextEditingController(
      text: '${product['stock_quantity'] ?? 0}',
    );
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تعيين الكمية'),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            labelText: context.tr('الكمية الجديدة'),
            border: const OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const AppText('إلغاء'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
            onPressed: () {
              final v = int.tryParse(controller.text.trim());
              Navigator.pop(ctx, v);
            },
            child: const AppText('حفظ'),
          ),
        ],
      ),
    );
    if (result == null) return;
    setState(() => _busyProducts.add(id));
    try {
      await _service.quickStock(id, set: result);
      await _load();
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(e.message)));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('تعذّر تحديث الكمية.')));
    } finally {
      setState(() => _busyProducts.remove(id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('إدارة المخزون'),
        actions: [
          IconButton(
            tooltip: context.tr('تحديث'),
            icon: _loadingAll
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) return const LoadingIndicator();
    if (_error != null) {
      return AppStateMessage(
        message: _error!,
        icon: Icons.error_outline,
        onRetry: _load,
      );
    }
    if (_lowStock.isEmpty) {
      return const AppStateMessage(
        message:
            'لا توجد منتجات مخزونها منخفض. كل منتجاتك متوفرة بكميات كافية ✅',
        icon: Icons.check_circle_outline,
      );
    }
    return RefreshIndicator(
      color: AppColors.emerald,
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: _lowStock.length,
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          final p = _lowStock[index];
          final id = (p['id'] as num?)?.toInt();
          final name = '${p['name'] ?? ''}';
          final stock = (p['stock_quantity'] as num?)?.toInt() ?? 0;
          final threshold = (p['low_stock_threshold'] as num?)?.toInt() ?? 5;
          final image = p['image'] as String?;
          final busy = _busyProducts.contains(id);
          final critical = stock == 0;

          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.cardSurface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: critical ? Colors.red.shade300 : context.cardBorder,
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: image != null
                          ? CachedNetworkImage(
                              imageUrl: image,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              errorWidget: (_, __, ___) => Container(
                                width: 48,
                                height: 48,
                                color: AppColors.bgLight,
                                child: const Icon(
                                  Icons.image_not_supported,
                                  color: AppColors.muted,
                                  size: 20,
                                ),
                              ),
                            )
                          : Container(
                              width: 48,
                              height: 48,
                              color: AppColors.bgLight,
                              child: const Icon(
                                Icons.inventory_2_outlined,
                                color: AppColors.muted,
                                size: 20,
                              ),
                            ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          AppText(
                            name,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            critical
                                ? 'نفد المخزون! 🔴'
                                : 'الكمية: $stock (حد التنبيه: $threshold)',
                            style: TextStyle(
                              fontSize: 12,
                              color: critical
                                  ? Colors.red
                                  : Colors.orange.shade800,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => _setExact(p),
                      child: const AppText('تعيين'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // أزرار الكمية السريعة
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _stockButton(
                      label: '+10',
                      color: AppColors.emerald,
                      onPressed: busy ? null : () => _quickStock(p, 10),
                    ),
                    const SizedBox(width: 8),
                    _stockButton(
                      label: '+5',
                      color: AppColors.emerald,
                      onPressed: busy ? null : () => _quickStock(p, 5),
                    ),
                    const SizedBox(width: 8),
                    _stockButton(
                      label: '+1',
                      color: AppColors.emerald,
                      onPressed: busy ? null : () => _quickStock(p, 1),
                    ),
                    const SizedBox(width: 8),
                    _stockButton(
                      label: '-1',
                      color: Colors.red.shade600,
                      onPressed: (busy || stock <= 0)
                          ? null
                          : () => _quickStock(p, -1),
                    ),
                    if (busy)
                      const Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _stockButton({
    required String label,
    required Color color,
    VoidCallback? onPressed,
  }) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: color,
        side: BorderSide(color: color.withValues(alpha: .5)),
        minimumSize: const Size(56, 36),
        padding: const EdgeInsets.symmetric(horizontal: 10),
      ),
      child: AppText(
        label,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 13,
          color: color,
        ),
      ),
    );
  }
}
