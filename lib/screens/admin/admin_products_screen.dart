import '../../theme/theme_switcher.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminProductsScreen extends StatefulWidget {
  final bool employeeMode;

  const AdminProductsScreen({super.key, this.employeeMode = false});

  @override
  State<AdminProductsScreen> createState() => _AdminProductsScreenState();
}

class _AdminProductsScreenState extends State<AdminProductsScreen> {
  final AdminService _service = AdminService();
  List<Product>? _products;
  String? _error;
  String _filter = 'pending';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final products = await _service.pendingProducts(
          filter: _filter, employeeMode: widget.employeeMode);
      setState(() => _products = products);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل المنتجات.');
    }
  }

  Future<void> _approve(Product product) async {
    try {
      await _service.approveProduct(product.id,
          employeeMode: widget.employeeMode);
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _reject(Product product) async {
    final controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: AppText('رفض "${product.name}"'),
        content: TextField(
            controller: controller,
            decoration: InputDecoration(
                labelText:
                    AppLocalizations.of(context).translate('سبب الرفض'))),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const AppText('إلغاء')),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.trim().isEmpty) return;
              try {
                await _service.rejectProduct(product.id, controller.text.trim(),
                    employeeMode: widget.employeeMode);
                if (ctx.mounted) Navigator.pop(ctx);
                _load();
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: AppText(e.message)));
                }
              }
            },
            child: const AppText('تأكيد الرفض'),
          ),
        ],
      ),
    );
  }

  Future<void> _edit(Product product) async {
    final name = TextEditingController(text: product.name);
    final description = TextEditingController(text: product.description ?? '');
    final price = TextEditingController(text: product.price.toStringAsFixed(2));
    final stock = TextEditingController(text: product.stockQuantity.toString());
    final formKey = GlobalKey<FormState>();
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: AppText('تعديل ${product.name}'),
        content: Form(
          key: formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: name,
                  decoration: InputDecoration(labelText: context.tr('اسم المنتج')),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? context.tr('مطلوب') : null,
                ),
                TextFormField(
                  controller: description,
                  decoration: InputDecoration(labelText: context.tr('الوصف')),
                  maxLines: 3,
                ),
                TextFormField(
                  controller: price,
                  decoration: InputDecoration(
                      labelText: context.tr('السعر (ل.س)'), suffixText: context.tr('ل.س')),
                  keyboardType: TextInputType.number,
                  validator: (value) => (double.tryParse(value ?? '') ?? 0) <= 0
                      ? context.tr('سعر غير صالح')
                      : null,
                ),
                TextFormField(
                  controller: stock,
                  decoration: InputDecoration(labelText: context.tr('المخزون')),
                  keyboardType: TextInputType.number,
                  validator: (value) => int.tryParse(value ?? '') == null
                      ? context.tr('كمية غير صالحة')
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('إلغاء'),
          ),
          FilledButton(
            onPressed: () {
              if (formKey.currentState!.validate()) {
                Navigator.pop(dialogContext, true);
              }
            },
            child: const AppText('حفظ'),
          ),
        ],
      ),
    );
    if (saved == true && product.category != null) {
      try {
        await _service.updateEmployeeProduct(
          id: product.id,
          name: name.text.trim(),
          description: description.text.trim(),
          categoryId: product.category!.id,
          price: double.parse(price.text),
          stockQuantity: int.parse(stock.text),
        );
        await _load();
      } on ApiException catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: AppText(e.message)));
        }
      }
    }
    name.dispose();
    description.dispose();
    price.dispose();
    stock.dispose();
  }

  Future<void> _archive(Product product) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const AppText('إخفاء المنتج'),
        content: const AppText('سيتم إخفاؤه مع الاحتفاظ بسجله وطلباته.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const AppText('إلغاء'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const AppText('إخفاء'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.archiveEmployeeProduct(product.id);
      await _load();
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
        title: const AppText('مراجعة المنتجات'),
        actions: const [ThemeToggleButton()],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'pending', label: AppText('معلّقة')),
                ButtonSegment(value: 'live', label: AppText('معتمدة')),
                ButtonSegment(value: 'draft', label: AppText('مسودات')),
              ],
              selected: {_filter},
              onSelectionChanged: (s) {
                setState(() => _filter = s.first);
                _load();
              },
            ),
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load,
                color: AppColors.emerald,
                child: _buildBody()),
          ),
        ],
      ),
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
          message: 'لا يوجد منتجات بهذا التصنيف.',
          icon: Icons.inventory_2_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _products!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final product = _products![index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AppText(product.name,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                if (product.vendor != null)
                  AppText(product.vendor!.storeName,
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                AppText(product.formattedPrice,
                    style: const TextStyle(color: AppColors.emeraldDark)),
                if (widget.employeeMode) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _edit(product),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const AppText('تعديل'),
                      ),
                      if (product.status != 'inactive')
                        OutlinedButton.icon(
                          onPressed: () => _archive(product),
                          icon: const Icon(Icons.visibility_off_outlined,
                              size: 18),
                          label: const AppText('إخفاء'),
                        ),
                    ],
                  ),
                ],
                if (_filter == 'pending') ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                            onPressed: () => _approve(product),
                            child: const AppText('موافقة')),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _reject(product),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger)),
                          child: const AppText('رفض'),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
