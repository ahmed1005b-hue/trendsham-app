import 'product.dart';

int? _toInt(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _toDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

class CartItemVariant {
  final int id;
  final String? color;
  final String? colorName;
  final String? size;
  final String? label;
  final int stockQuantity;

  const CartItemVariant({
    required this.id,
    this.color,
    this.colorName,
    this.size,
    this.label,
    this.stockQuantity = 0,
  });

  factory CartItemVariant.fromJson(Map<String, dynamic> json) {
    return CartItemVariant(
      id: _toInt(json['id']) ?? 0,
      color: json['color']?.toString(),
      colorName: json['color_name']?.toString(),
      size: json['size']?.toString(),
      label: json['label']?.toString(),
      stockQuantity: _toInt(json['stock_quantity']) ?? 0,
    );
  }
}

class CartItem {
  final int id;
  final int quantity;
  final double unitPrice;
  final double originalUnitPrice;
  final bool hasActiveDeal;
  final int? dealDiscountPercentage;
  final double subtotal;
  final Product product;
  final int? variantId;
  final CartItemVariant? variant;

  CartItem({
    required this.id,
    required this.quantity,
    required this.unitPrice,
    required this.originalUnitPrice,
    required this.hasActiveDeal,
    this.dealDiscountPercentage,
    required this.subtotal,
    required this.product,
    this.variantId,
    this.variant,
  });

  factory CartItem.fromJson(Map<String, dynamic> json) {
    final product = json['product'] is Map
        ? Product.fromJson(Map<String, dynamic>.from(json['product'] as Map))
        : Product.fromJson(const <String, dynamic>{});
    final quantity = _toInt(json['quantity']) ?? 0;
    final unitPrice = _toDouble(json['unit_price'], product.displayPrice);
    final originalUnitPrice =
        _toDouble(json['original_unit_price'], product.price);
    final variant = json['variant'] is Map
        ? CartItemVariant.fromJson(Map<String, dynamic>.from(json['variant'] as Map))
        : null;
    return CartItem(
      id: _toInt(json['id']) ?? 0,
      quantity: quantity,
      unitPrice: unitPrice,
      originalUnitPrice: originalUnitPrice,
      hasActiveDeal: json['has_active_deal'] == true ||
          product.hasActiveDeal ||
          unitPrice < originalUnitPrice,
      dealDiscountPercentage:
          _toInt(json['deal_discount_percentage']) ?? product.displayDiscountPercentage,
      subtotal: _toDouble(json['subtotal'], unitPrice * quantity),
      product: product,
      variantId: _toInt(json['variant_id']),
      variant: variant,
    );
  }
}
