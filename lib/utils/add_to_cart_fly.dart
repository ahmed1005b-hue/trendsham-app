import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/auth_provider.dart';
import '../providers/cart_provider.dart';
import '../screens/home/main_screen.dart';
import '../widgets/fly_to_cart.dart';
import 'auth_prompt.dart';
import '../l10n/app_localizations.dart';

class AddToCartFly {
  static Future<bool> add(
    BuildContext context, {
    required int productId,
    BuildContext? sourceContext,
    String? imageUrl,
    int quantity = 1,
    double? specialPrice,
    int? discountPercentage,
    int? variantId,
  }) async {
    final auth = context.read<AuthProvider>();
    if (!auth.isLoggedIn) {
      final ok = await showAuthRequiredDialog(context);
      if (!ok || !context.mounted) return false;
    }
    if (context.read<AuthProvider>().user?.role != 'customer') {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('الشراء متاح لحسابات العملاء فقط.')));
      }
      return false;
    }
    try {
      await context.read<CartProvider>().add(productId,
          quantity: quantity,
          specialPrice: specialPrice,
          discountPercentage: discountPercentage,
          variantId: variantId);
      if (!context.mounted) return true;
      RenderBox? box;
      if (sourceContext != null) {
        final obj = sourceContext.findRenderObject();
        if (obj is RenderBox && obj.hasSize) box = obj;
      }
      await FlyToCart.run(
        context,
        targetKey: CartNavTarget.iconKey,
        sourceOffset: box?.localToGlobal(box.size.center(Offset.zero)),
        imageUrl: imageUrl,
      );
      return true;
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText('تعذّر إضافة المنتج: $e')));
      }
      return false;
    }
  }
}
