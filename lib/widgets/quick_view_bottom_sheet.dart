import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../models/product.dart';
import '../utils/add_to_cart_fly.dart';
import '../l10n/app_localizations.dart';

class QuickViewBottomSheet extends StatefulWidget {
  const QuickViewBottomSheet({super.key, required this.product});

  final Product product;

  @override
  State<QuickViewBottomSheet> createState() => _QuickViewBottomSheetState();
}

class _QuickViewBottomSheetState extends State<QuickViewBottomSheet> {
  int _qty = 1;
  int? _variantId;
  String? _color;
  String? _size;

  Product get product => widget.product;
  List<ProductVariant> get _variants => product.variants;
  bool get _hasVariants => _variants.isNotEmpty;

  List<String> get _colorKeys => _variants
      .map((v) => v.color ?? '')
      .where((c) => c.isNotEmpty)
      .toSet()
      .toList();
  List<String> get _sizeKeys => _variants
      .map((v) => v.size ?? '')
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  @override
  void initState() {
    super.initState();
    if (_hasVariants) {
      final first = _variants.firstWhere((v) => v.stockQuantity > 0,
          orElse: () => _variants.first);
      _variantId = first.id;
      _color = first.color;
      _size = first.size;
    }
  }

  ProductVariant? get _selectedVariant {
    if (!_hasVariants) return null;
    if (_variantId != null) {
      for (final v in _variants) {
        if (v.id == _variantId) return v;
      }
    }
    for (final v in _variants) {
      if ((_color == null || v.color == _color) &&
          (_size == null || v.size == _size)) {
        return v;
      }
    }
    return _variants.first;
  }

  bool get _outOfStock => _hasVariants
      ? ((_selectedVariant?.stockQuantity ?? 0) <= 0)
      : !product.inStock;
  double get _effectiveUnitPrice =>
      product.displayPrice + (_selectedVariant?.priceAdjustment ?? 0);

  Color _swatchColor(String? code) {
    if (code == null || code.isEmpty) return AppColors.muted;
    try {
      final hex = code.replaceAll('#', '');
      return Color(int.parse('FF$hex', radix: 16));
    } catch (_) {
      return AppColors.muted;
    }
  }

  void _selectColor(String color) {
    final candidates = _variants.where((v) => v.color == color).toList();
    final match = candidates.firstWhere(
        (v) => v.size == _size && v.stockQuantity > 0,
        orElse: () => candidates.firstWhere((v) => v.stockQuantity > 0,
            orElse: () => candidates.first));
    setState(() {
      _color = color;
      _size = match.size;
      _variantId = match.id;
      _qty = 1;
    });
  }

  void _selectSize(String size) {
    ProductVariant? match;
    for (final v in _variants) {
      if (v.size == size && (_color == null || v.color == _color)) {
        match = v;
        break;
      }
    }
    match ??= _variants.firstWhere((v) => v.size == size,
        orElse: () => _variants.first);
    setState(() {
      _size = size;
      _color = match!.color ?? _color;
      _variantId = match.id;
      _qty = 1;
    });
  }

  String? get _selectedImageUrl {
    if (_color != null) {
      for (final img in product.images) {
        if (img.color == _color) return img.url;
      }
    }
    return product.primaryImage?.url;
  }

  @override
  Widget build(BuildContext context) {
    final deal = product.hasActiveDeal;
    final discount = product.displayDiscountPercentage;
    final canAdd = !_outOfStock && (!_hasVariants || _variantId != null);
    final maxQty = _hasVariants ? (_selectedVariant?.stockQuantity ?? 0) : 999;

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 92,
                      height: 92,
                      child: _selectedImageUrl != null
                          ? CachedNetworkImage(
                              imageUrl: _selectedImageUrl!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            )
                          : Container(
                              color: Theme.of(context)
                                  .colorScheme
                                  .surfaceContainerHighest,
                              child: const Icon(
                                  Icons.image_not_supported_outlined,
                                  size: 32),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppText(product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color:
                                    Theme.of(context).colorScheme.onSurface)),
                        const SizedBox(height: 6),
                        if (deal)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: AppText(
                                '${product.dealLabel ?? 'عرض اليوم'} • خصم %${discount ?? 0}',
                                style: const TextStyle(
                                    color: AppColors.primaryDark,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ),
                        const SizedBox(height: 10),
                        AppText('${_effectiveUnitPrice.toStringAsFixed(0)} ل.س',
                            style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w900,
                                color: AppColors.primary)),
                        if (_outOfStock)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: AppText('غير متوفر',
                                style: TextStyle(
                                    color: AppColors.danger,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_hasVariants && _colorKeys.isNotEmpty) ...[
                const SizedBox(height: 14),
                const AppText('اللون:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _colorKeys.map((hex) {
                    final selected = _color == hex;
                    final available = _variants.any(
                        (v) => v.color == hex && v.stockQuantity > 0);
                    final name = _variants
                        .firstWhere((v) => v.color == hex)
                        .colorName;
                    return GestureDetector(
                      onTap: available ? () => _selectColor(hex) : null,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: selected
                                  ? AppColors.primary
                                  : Theme.of(context)
                                      .colorScheme
                                      .outlineVariant,
                              width: selected ? 2 : 1),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Container(
                              width: 14,
                              height: 14,
                              decoration: BoxDecoration(
                                  color: _swatchColor(hex),
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          AppText(name ?? hex,
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: selected
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                  decoration: available
                                      ? null
                                      : TextDecoration.lineThrough,
                                  color: available ? null : AppColors.muted)),
                        ]),
                      ),
                    );
                  }).toList(),
                ),
              ],
              if (_hasVariants && _sizeKeys.isNotEmpty) ...[
                const SizedBox(height: 12),
                const AppText('المقاس:',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _sizeKeys.map((sz) {
                    final selected = _size == sz;
                    final available = _variants.any((v) =>
                        v.size == sz &&
                        (_color == null || v.color == _color) &&
                        v.stockQuantity > 0);
                    return ChoiceChip(
                      label: AppText(sz),
                      selected: selected,
                      onSelected:
                          available ? (_) => _selectSize(sz) : null,
                      selectedColor: AppColors.primary.withValues(alpha: 0.15),
                      labelStyle: TextStyle(
                          color: available ? null : AppColors.muted,
                          decoration:
                              available ? null : TextDecoration.lineThrough),
                    );
                  }).toList(),
                ),
              ],
              const SizedBox(height: 14),
              Row(children: [
                const AppText('الكمية: ',
                    style:
                        TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                const SizedBox(width: 8),
                Container(
                  decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(8)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    _btn(Icons.remove,
                        _qty > 1 ? () => setState(() => _qty--) : null),
                    Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: AppText('$_qty',
                            style:
                                const TextStyle(fontWeight: FontWeight.bold))),
                    _btn(Icons.add, _qty < maxQty || !_hasVariants
                        ? () => setState(() => _qty++)
                        : null),
                  ]),
                ),
                if (_hasVariants && _selectedVariant != null)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(start: 10),
                    child: AppText('متوفر: ${_selectedVariant!.stockQuantity}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ),
              ]),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton.icon(
                  onPressed: canAdd
                      ? () {
                          Navigator.of(context).pop();
                          AddToCartFly.add(
                            context,
                            productId: product.id,
                            quantity: _qty,
                            variantId: _variantId,
                            specialPrice: deal || _hasVariants
                                ? _effectiveUnitPrice
                                : null,
                            discountPercentage: deal ? discount : null,
                          );
                        }
                      : null,
                  icon: const Icon(Icons.add_shopping_cart_rounded, size: 20),
                  label: AppText(_hasVariants && _variantId == null ? 'اختر اللون/المقاس' : 'أضف إلى السلة',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      elevation: 0),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: OutlinedButton.icon(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.visibility_outlined, size: 20),
                  label: const AppText('عرض التفاصيل الكاملة',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                      foregroundColor:
                          Theme.of(context).colorScheme.onSurface,
                      side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .outlineVariant),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12))),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _btn(IconData icon, VoidCallback? onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
          padding: const EdgeInsets.all(6),
          child: Icon(icon,
              size: 18,
              color: onTap == null ? AppColors.muted : AppColors.darkInk)),
    );
  }
}
