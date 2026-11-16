import 'dart:math' as math show max, pi, sin;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

class FlyToCart {
  static Future<void> run(
    BuildContext context, {
    required GlobalKey targetKey,
    GlobalKey? sourceKey,
    Offset? sourceOffset,
    String? imageUrl,
    Widget? child,
  }) async {
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    final targetContext = targetKey.currentContext;
    if (overlay == null || targetContext == null) return;
    RenderBox? sourceBox;
    if (sourceKey?.currentContext != null) {
      final obj = sourceKey!.currentContext!.findRenderObject();
      if (obj is RenderBox && obj.hasSize) sourceBox = obj;
    }
    final targetObj = targetContext.findRenderObject();
    if (targetObj is! RenderBox || !targetObj.hasSize) return;
    final targetPos = targetObj.localToGlobal(targetObj.size.center(Offset.zero));
    final start = sourceBox != null
        ? sourceBox.localToGlobal(sourceBox.size.center(Offset.zero))
        : (sourceOffset ?? targetPos - const Offset(0, 120));
    final entry = OverlayEntry(builder: (ctx) => _FlyToCartOverlay(start: start, end: targetPos, imageUrl: imageUrl, child: child));
    overlay.insert(entry);
    await Future<void>.delayed(const Duration(milliseconds: 820));
    entry.remove();
  }
}

class _FlyToCartOverlay extends StatefulWidget {
  final Offset start;
  final Offset end;
  final String? imageUrl;
  final Widget? child;
  const _FlyToCartOverlay({required this.start, required this.end, this.imageUrl, this.child});
  @override
  State<_FlyToCartOverlay> createState() => _FlyToCartOverlayState();
}

class _FlyToCartOverlayState extends State<_FlyToCartOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 760));
  late final Animation<double> _curve = CurvedAnimation(parent: _controller, curve: Curves.easeInOutCubic);
  late final Animation<double> _scale = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.35, end: 1.0).chain(CurveTween(curve: Curves.easeOutBack)), weight: 25),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.18).chain(CurveTween(curve: Curves.easeIn)), weight: 75),
  ]).animate(_controller);
  late final Animation<double> _opacity = TweenSequence<double>([
    TweenSequenceItem(tween: ConstantTween(1.0), weight: 78),
    TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.0), weight: 22),
  ]).animate(_controller);
  @override
  void initState() {
    super.initState();
    _controller.forward();
  }
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _curve.value;
        final dx = widget.start.dx + (widget.end.dx - widget.start.dx) * t;
        final arc = math.sin(t * math.pi) * 90;
        final dy = widget.start.dy + (widget.end.dy - widget.start.dy) * t - arc;
        final size = 54.0 * _scale.value;
        return Positioned(
          left: dx - size / 2,
          top: dy - size / 2,
          child: IgnorePointer(
            child: Opacity(
              opacity: _opacity.value,
              child: SizedBox(
                width: math.max(10, size),
                height: math.max(10, size),
                child: widget.child ?? _defaultChip(),
              ),
            ),
          ),
        );
      },
    );
  }
  Widget _defaultChip() {
    return DecoratedBox(
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 10, offset: const Offset(0, 4))]),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: widget.imageUrl != null && widget.imageUrl!.isNotEmpty
            ? CachedNetworkImage(imageUrl: widget.imageUrl!, fit: BoxFit.contain, errorWidget: (_, __, ___) => const Icon(Icons.shopping_bag, color: Colors.orange))
            : const ColoredBox(color: Colors.orange, child: Icon(Icons.shopping_bag, color: Colors.white, size: 22)),
      ),
    );
  }
}
