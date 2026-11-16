import 'package:flutter/material.dart';
import '../config/theme.dart';

/// ويدجت تحريك الـ Shimmer الأساسي
/// يقوم بعمل تأثير مسح ضوئي متحرك (Shimmer Wave Effect) يحاكي تحميل البيانات
class ShimmerLoading extends StatefulWidget {
  const ShimmerLoading({
    super.key,
    required this.child,
    this.baseColor,
    this.highlightColor,
  });

  final Widget child;
  final Color? baseColor;
  final Color? highlightColor;

  static ShimmerLoadingState? of(BuildContext context) {
    return context.findAncestorStateOfType<ShimmerLoadingState>();
  }

  @override
  State<ShimmerLoading> createState() => ShimmerLoadingState();
}

class ShimmerLoadingState extends State<ShimmerLoading>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Listenable get shimmerChanges => _controller;

  LinearGradient get gradient {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = widget.baseColor ??
        (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E5E0));
    final highlight = widget.highlightColor ??
        (isDark ? const Color(0xFF3D3D3D) : const Color(0xFFF7F6F2));

    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [base, highlight, base],
      stops: const [0.1, 0.5, 0.9],
      transform: _SlidingGradientTransform(slidePercent: _controller.value),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => widget.child,
    );
  }
}

class _SlidingGradientTransform extends GradientTransform {
  const _SlidingGradientTransform({required this.slidePercent});

  final double slidePercent;

  @override
  Matrix4? transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(bounds.width * (slidePercent * 2 - 1), 0, 0);
  }
}

/// صندوق هيكلي فردي (Shimmer Box)
class ShimmerBox extends StatelessWidget {
  const ShimmerBox({
    super.key,
    this.width,
    this.height,
    this.borderRadius = 8,
    this.shape = BoxShape.rectangle,
    this.margin,
  });

  final double? width;
  final double? height;
  final double borderRadius;
  final BoxShape shape;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final shimmer = ShimmerLoading.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fallbackColor =
        isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE7E5E0);

    final decoration = BoxDecoration(
      shape: shape,
      borderRadius:
          shape == BoxShape.rectangle ? BorderRadius.circular(borderRadius) : null,
      gradient: shimmer?.gradient,
      color: shimmer == null ? fallbackColor : null,
    );

    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: decoration,
    );
  }
}

/// بطاقة منتج هيكلية (Product Card Skeleton)
/// تطابق أبعاد وشكل ProductCard الأصلي
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBg = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final borderColor = isDark ? const Color(0xFF333333) : AppColors.border;

    return Container(
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: borderColor, width: 0.8),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // مساحة الصورة
          Expanded(
            flex: 6,
            child: ShimmerBox(
              width: double.infinity,
              height: double.infinity,
              borderRadius: 9,
            ),
          ),
          // تفاصيل المنتج
          Expanded(
            flex: 5,
            child: Padding(
              padding: EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      ShimmerBox(width: 50, height: 10, borderRadius: 4),
                      Spacer(),
                      ShimmerBox(width: 30, height: 10, borderRadius: 4),
                    ],
                  ),
                  SizedBox(height: 6),
                  ShimmerBox(width: double.infinity, height: 12, borderRadius: 4),
                  SizedBox(height: 4),
                  ShimmerBox(width: 90, height: 12, borderRadius: 4),
                  Spacer(),
                  Row(
                    children: [
                      ShimmerBox(width: 65, height: 14, borderRadius: 4),
                      SizedBox(width: 6),
                      ShimmerBox(
                        width: 40,
                        height: 11,
                        borderRadius: 3,
                        margin: EdgeInsets.only(top: 2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// شبكة بطاقات المنتجات الهيكلية (Product Grid Skeleton)
class ProductGridSkeleton extends StatelessWidget {
  const ProductGridSkeleton({
    super.key,
    this.itemCount = 6,
    this.padding = const EdgeInsets.all(12),
  });

  final int itemCount;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: GridView.builder(
        padding: padding,
        physics: const NeverScrollableScrollPhysics(),
        shrinkWrap: true,
        itemCount: itemCount,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          childAspectRatio: 0.68,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
        ),
        itemBuilder: (_, __) => const ProductCardSkeleton(),
      ),
    );
  }
}

/// هيكل الأقسام الدائرية (Category Skeleton)
class CategoryListSkeleton extends StatelessWidget {
  const CategoryListSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerLoading(
      child: SizedBox(
        height: 86,
        child: ListView.separated(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          scrollDirection: Axis.horizontal,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: 6,
          separatorBuilder: (_, __) => const SizedBox(width: 14),
          itemBuilder: (_, __) => const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ShimmerBox(
                width: 52,
                height: 52,
                shape: BoxShape.circle,
              ),
              SizedBox(height: 6),
              ShimmerBox(
                width: 44,
                height: 10,
                borderRadius: 4,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// هيكل بانر العروض المميزة (Spotlight / Deals Skeleton)
class SpotlightSkeleton extends StatelessWidget {
  const SpotlightSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return const ShimmerLoading(
      child: Padding(
        padding: EdgeInsets.fromLTRB(14, 14, 14, 12),
        child: ShimmerBox(
          width: double.infinity,
          height: 152,
          borderRadius: 18,
        ),
      ),
    );
  }
}

/// هيكل قائمة عامة: صف بصورة/أيقونة وسطرين (السلة، المتاجر، الكوبونات، النقاط...).
class ListSkeleton extends StatelessWidget {
  const ListSkeleton({
    super.key,
    this.itemCount = 6,
    this.leadingSize = 56,
    this.circleLeading = false,
    this.padding = const EdgeInsets.all(16),
  });

  final int itemCount;
  final double leadingSize;
  final bool circleLeading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ShimmerLoading(
        child: ListView.separated(
          padding: padding,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: itemCount,
          separatorBuilder: (_, __) => const SizedBox(height: 16),
          itemBuilder: (_, __) => Row(
            children: [
              ShimmerBox(
                width: leadingSize,
                height: leadingSize,
                borderRadius: 10,
                shape: circleLeading ? BoxShape.circle : BoxShape.rectangle,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14),
                    SizedBox(height: 8),
                    FractionallySizedBox(
                      widthFactor: 0.55,
                      child: ShimmerBox(height: 12),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// هيكل صفحة المنتج: صورة كبيرة ثم العنوان والسعر والوصف.
class ProductDetailSkeleton extends StatelessWidget {
  const ProductDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ShimmerLoading(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: const [
            AspectRatio(aspectRatio: 1, child: ShimmerBox(borderRadius: 0)),
            Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ShimmerBox(height: 20),
                  SizedBox(height: 10),
                  FractionallySizedBox(
                      widthFactor: 0.6, child: ShimmerBox(height: 20)),
                  SizedBox(height: 18),
                  FractionallySizedBox(
                      widthFactor: 0.35, child: ShimmerBox(height: 26)),
                  SizedBox(height: 24),
                  ShimmerBox(height: 12),
                  SizedBox(height: 8),
                  ShimmerBox(height: 12),
                  SizedBox(height: 8),
                  FractionallySizedBox(
                      widthFactor: 0.8, child: ShimmerBox(height: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// هيكل صفحة المتجر: غلاف وشعار ثم شبكة منتجات.
class StoreSkeleton extends StatelessWidget {
  const StoreSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'جارٍ التحميل',
      child: ShimmerLoading(
        child: ListView(
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: const [
            ShimmerBox(height: 140, borderRadius: 0),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Row(
                children: [
                  ShimmerBox(width: 64, height: 64, shape: BoxShape.circle),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ShimmerBox(height: 16),
                        SizedBox(height: 8),
                        FractionallySizedBox(
                            widthFactor: 0.5, child: ShimmerBox(height: 12)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            _SkeletonGrid(),
          ],
        ),
      ),
    );
  }
}

class _SkeletonGrid extends StatelessWidget {
  const _SkeletonGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.all(12),
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      itemCount: 4,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.68,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (_, __) => const ProductCardSkeleton(),
    );
  }
}
