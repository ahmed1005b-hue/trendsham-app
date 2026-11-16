import '../../services/loyalty_service.dart';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../models/cart_item.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/auth_prompt.dart';
import '../checkout/checkout_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

class CartScreen extends StatefulWidget {
  final bool embedded;

  const CartScreen({super.key, this.embedded = false});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  @override
  void initState() {
    super.initState();
    if (!widget.embedded && context.read<AuthProvider>().isLoggedIn) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => context.read<CartProvider>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!context.watch<AuthProvider>().isLoggedIn) {
      return Scaffold(
        appBar: AppBar(title: const AppText('سلة التسوق')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline, size: 48),
                const SizedBox(height: 12),
                const AppText('سجّل الدخول للوصول إلى سلة التسوق.'),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => showAuthRequiredDialog(context),
                  child: const AppText('تسجيل الدخول أو إنشاء حساب'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final cart = context.watch<CartProvider>();

    if (cart.isLoading && cart.items.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const AppText('سلة التسوق')),
        body: const ListSkeleton(itemCount: 4, leadingSize: 72),
      );
    }

    final body = cart.items.isEmpty
        ? _EmptyCart(
            onContinue: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                // إذا كانت السلة مُدرجة داخل التبويب السفلي (Embedded)، ننتقل للشاشة الرئيسية
                Navigator.of(context, rootNavigator: true)
                    .pushNamedAndRemoveUntil('/', (route) => false);
              }
            },
          )
        : Column(
            children: [
              if (cart.error != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  color: AppColors.danger.withValues(alpha: 0.1),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: AppColors.danger, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: AppText(cart.error!,
                            style: const TextStyle(
                                color: AppColors.danger, fontSize: 12)),
                      ),
                      IconButton(
                        tooltip: context.tr('تحديث السلة'),
                        icon: const Icon(Icons.refresh, size: 18),
                        onPressed: cart.load,
                      ),
                    ],
                  ),
                ),
              Expanded(
                child: ListView.separated(
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _CartItemTile(item: cart.items[index]),
                ),
              ),
              _CartSummary(cart: cart),
            ],
          );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: const AppText('سلة التسوق'),
        actions: [
          if (cart.items.isNotEmpty)
            TextButton(
              onPressed: () => _confirmClear(context, cart),
              child:
                  const AppText('مسح الكل', style: TextStyle(color: Colors.white)),
            ),
        ],
      ),
      body: body,
    );
  }

  void _confirmClear(BuildContext context, CartProvider cart) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('مسح السلة'),
        content: const AppText('هل أنت متأكد من رغبتك في إفراغ سلة التسوق؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const AppText('إلغاء')),
          TextButton(
            onPressed: () {
              cart.clearCart(); // إفراغ فوري محلياً، المزامنة في الخلفية
              Navigator.pop(ctx);
            },
            child: const AppText('نعم، مسح',
                style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
  }
}

class _EmptyCart extends StatelessWidget {
  final VoidCallback onContinue;
  const _EmptyCart({required this.onContinue});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.shopping_cart_outlined,
                  size: 80, color: AppColors.primary),
            ),
            const SizedBox(height: 24),
            const AppText('سلتك فارغة حالياً',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            const AppText(
              'يبدو أنك لم تضف أي منتجات إلى سلتك بعد. ابدأ بالتسوق الآن واكتشف أفضل العروض!',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.muted, height: 1.5),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onContinue,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                child: const AppText('ابدأ التسوق'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartItemTile extends StatelessWidget {
  final CartItem item;
  const _CartItemTile({required this.item});

  @override
  Widget build(BuildContext context) {
    final cart = context.read<CartProvider>();
    final isDiscounted = item.originalUnitPrice > item.unitPrice;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.4),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Product Image
              Container(
                width: 100,
                color: isDark ? Colors.transparent : AppColors.bgLight,
                child: item.product.primaryImage != null
                    ? CachedNetworkImage(
                        imageUrl: item.product.primaryImage!.url,
                        fit: BoxFit.cover,
                      )
                    : const Center(
                        child: Icon(Icons.image_not_supported_outlined)),
              ),
              // Details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: AppText(
                              item.product.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                height: 1.3,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _confirmDelete(context, cart),
                            child: Icon(Icons.close,
                                size: 20, color: colorScheme.onSurfaceVariant),
                          ),
                        ],
                      ),
                      if (item.product.vendor != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: AppText(
                            item.product.vendor!.storeName,
                            style: TextStyle(
                                color:
                                    isDark ? AppColors.gold : AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      if (item.variant?.label != null &&
                          item.variant!.label!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 3),
                          child: AppText(
                            item.variant!.label!,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11),
                          ),
                        ),
                      if (item.product.description != null &&
                          item.product.description!.trim().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: AppText(
                            item.product.description!.trim(),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 11),
                          ),
                        ),
                      const Spacer(),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (isDiscounted)
                                AppText(
                                  '${item.originalUnitPrice.toStringAsFixed(0)} ${cart.currency}',
                                  style: TextStyle(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    decoration: TextDecoration.lineThrough,
                                  ),
                                ),
                              AppText(
                                '${item.unitPrice.toStringAsFixed(0)} ${cart.currency}',
                                style: TextStyle(
                                  color: isDark
                                      ? AppColors.gold
                                      : AppColors.primaryDark,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          _QuantitySelector(
                            quantity: item.quantity,
                            onChanged: (val) =>
                                cart.updateQuantity(item.id, val),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CartProvider cart) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: AppText('تم حذف ${item.product.name}'),
        action: SnackBarAction(
          label: 'تراجع',
          onPressed: () => cart.add(item.product.id,
              quantity: item.quantity, variantId: item.variantId),
        ),
      ),
    );
    cart.remove(item.id);
  }
}

class _QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;

  const _QuantitySelector({required this.quantity, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
        color: colorScheme.surface,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn(context, Icons.remove,
              quantity > 1 ? () => onChanged(quantity - 1) : null),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: AppText('$quantity',
                style: TextStyle(
                    fontWeight: FontWeight.bold, color: colorScheme.onSurface)),
          ),
          _buildBtn(context, Icons.add, () => onChanged(quantity + 1)),
        ],
      ),
    );
  }

  Widget _buildBtn(BuildContext context, IconData icon, VoidCallback? onTap) {
    final colorScheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        child: Icon(icon,
            size: 18,
            color: onTap == null
                ? colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                : colorScheme.onSurface),
      ),
    );
  }
}

class _CartSummary extends StatelessWidget {
  final CartProvider cart;
  const _CartSummary({required this.cart});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final colorScheme = Theme.of(context).colorScheme;

    final savings = cart.savings;
    final subtotal = cart.subtotal;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (savings > 0)
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding:
                    const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.green.withValues(alpha: 0.15)
                      : const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.celebration_outlined,
                        color: Colors.green, size: 18),
                    const SizedBox(width: 8),
                    AppText(
                      'لقد وفرت ${savings.toStringAsFixed(0)} ${cart.currency} في هذه الطلبية!',
                      style: TextStyle(
                          color: isDark ? Colors.greenAccent : Colors.green,
                          fontSize: 12,
                          fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText('المجموع الفرعي',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                AppText('${subtotal.toStringAsFixed(0)} ${cart.currency}',
                    style: TextStyle(color: colorScheme.onSurface)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText('الخصومات',
                    style: TextStyle(color: colorScheme.onSurfaceVariant)),
                AppText('- ${savings.toStringAsFixed(0)} ${cart.currency}',
                    style: const TextStyle(color: Colors.green)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText('الإجمالي',
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: colorScheme.onSurface)),
                AppText(
                  '${cart.total.toStringAsFixed(0)} ${cart.currency}',
                  style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.gold : AppColors.primary),
                ),
              ],
            ),
            if (cart.willEarnPoints != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Row(children: [
                  const Icon(Icons.diamond_outlined, size: 16, color: Color(0xFF9A7425)),
                  const SizedBox(width: 4),
                  Expanded(
                    child: AppText(
                      cart.willEarnPoints! > 0
                          ? 'ستكسب ${pointsLabel(cart.willEarnPoints!)} عند استلام الطلب'
                          : 'أضف ${cart.pointsMissing.toStringAsFixed(0)} ${cart.currency} لتكسب أول نقطة',
                      style: const TextStyle(color: Color(0xFF9A7425), fontSize: 13),
                    ),
                  ),
                ]),
              ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckoutScreen()),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      isDark ? AppColors.brandGreenLight : AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                ),
                child: const AppText('إتمام عملية الشراء',
                    style:
                        TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
