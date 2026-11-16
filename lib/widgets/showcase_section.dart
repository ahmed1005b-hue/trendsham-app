import 'dart:async';
import 'dart:math' as math;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';

double _num(dynamic v) => double.tryParse(v?.toString() ?? '') ?? 0;
Color _hex(String h) => Color(int.parse(h.replaceFirst('#', '0xFF')));

/// روابط asset() من السيرفر قد تحمل localhost؛ نحوّلها لعنوان السيرفر المضبوط.
String? _media(dynamic raw) {
  final url = raw?.toString();
  if (url == null || url.isEmpty) return null;
  final uri = Uri.tryParse(url);
  if (uri != null && uri.hasAuthority) {
    if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
      return '${ApiConfig.storageBaseUrl}${uri.path}';
    }
    return url;
  }
  final path = url.startsWith('/') ? url : '/storage/$url';
  return '${ApiConfig.storageBaseUrl}$path';
}

class ShowcaseProduct {
  final int id;
  final String slug;
  final String name;
  final double price;
  final double? oldPrice;
  final String? imageUrl;

  /// صور البطاقة (حتى 5) تتقلّب تلقائياً كما في الويب؛ تعود للصورة الرئيسية
  /// إن كان السيرفر أقدم ولا يرسل `images`.
  final List<String> images;
  final double? rating;
  final int reviewsCount;

  ShowcaseProduct.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        slug = (j['slug'] ?? '').toString(),
        name = (j['name'] ?? '').toString(),
        price = _num(j['price']),
        oldPrice = j['old_price'] == null ? null : _num(j['old_price']),
        imageUrl = _media(j['image_url']),
        images = _cardImages(j['images'], _media(j['image_url'])),
        rating = j['rating'] == null ? null : _num(j['rating']),
        reviewsCount = (j['reviews_count'] as num?)?.toInt() ?? 0;
}

List<String> _cardImages(dynamic raw, String? fallback) {
  final list = <String>[];
  if (raw is List) {
    for (final e in raw) {
      final url = _media(e);
      if (url != null && !list.contains(url)) list.add(url);
    }
  }
  if (list.isEmpty && fallback != null) list.add(fallback);
  return list.take(5).toList();
}

class ShowcaseData {
  final int id;
  final String placement;
  final String title;
  final String? subtitle;
  final String sponsoredLabel;
  final List<Color> colors;
  final String direction; // vertical | horizontal | diagonal
  final bool lightText;
  final Color? textColor; // لون الخط الذي اختاره البائع
  final String? backgroundUrl; // صورة خلفية اختيارية فوق التدرج
  final int storeId;
  final String storeName;
  final String? storeLogo;
  final List<ShowcaseProduct> products;

  ShowcaseData.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        placement = (j['placement'] ?? '').toString(),
        title = (j['title'] ?? '').toString(),
        subtitle = j['subtitle']?.toString(),
        sponsoredLabel = (j['sponsored_label'] ?? 'إعلان').toString(),
        colors = ((j['gradient']['colors']) as List)
            .map((e) => _hex(e.toString()))
            .toList(),
        direction = (j['gradient']['direction'] ?? 'diagonal').toString(),
        lightText = j['text_color'] != 'dark',
        textColor = j['text_hex'] is String && (j['text_hex'] as String).length == 7
            ? _hex(j['text_hex'] as String)
            : null,
        backgroundUrl = _media(j['background_url']),
        storeId = j['store']['id'] as int,
        storeName = (j['store']['name'] ?? '').toString(),
        storeLogo = _media(j['store']['logo_url']),
        products = ((j['products'] ?? []) as List)
            .map((e) => ShowcaseProduct.fromJson(e as Map<String, dynamic>))
            .toList();
}

/// قسم عرض مُؤجَّر على الشاشة الرئيسية: تدرج ألوان + رأس المتجر + بطاقات منتجات أفقية.
class ShowcaseSection extends StatefulWidget {
  final ShowcaseData data;
  final void Function(ShowcaseProduct product) onProductTap;
  final VoidCallback onStoreTap;
  final VoidCallback? onImpression; // يُستدعى مرة واحدة عند أول ظهور

  const ShowcaseSection({
    super.key,
    required this.data,
    required this.onProductTap,
    required this.onStoreTap,
    this.onImpression,
  });

  @override
  State<ShowcaseSection> createState() => _ShowcaseSectionState();
}

class _ShowcaseSectionState extends State<ShowcaseSection> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => widget.onImpression?.call());
  }

  Alignment get _begin {
    switch (widget.data.direction) {
      case 'vertical':
        return Alignment.topCenter;
      case 'horizontal':
        return Alignment.centerRight;
      default:
        return Alignment.topRight;
    }
  }

  Alignment get _end {
    switch (widget.data.direction) {
      case 'vertical':
        return Alignment.bottomCenter;
      case 'horizontal':
        return Alignment.centerLeft;
      default:
        return Alignment.bottomLeft;
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    final fg = d.textColor ?? (d.lightText ? Colors.white : const Color(0xFF111111));

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: _begin, end: _end, colors: d.colors),
        image: d.backgroundUrl == null
            ? null
            : DecorationImage(
                image: NetworkImage(d.backgroundUrl!),
                fit: BoxFit.cover,
                onError: (_, __) {}, // تعذّر التحميل: يبقى التدرج
              ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // الرأس: شعار المتجر + الاسم + وسم إعلان + زر الزيارة
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: fg.withValues(alpha: 0.15),
                  backgroundImage:
                      d.storeLogo != null ? NetworkImage(d.storeLogo!) : null,
                  child: d.storeLogo == null
                      ? Icon(Icons.storefront_rounded, color: fg)
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(d.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: fg,
                              fontSize: 17,
                              fontWeight: FontWeight.bold)),
                      if (d.subtitle != null && d.subtitle!.isNotEmpty)
                        AppText(d.subtitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: fg.withValues(alpha: 0.85),
                                fontSize: 13)),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: fg.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: AppText(d.sponsoredLabel,
                      style: TextStyle(color: fg, fontSize: 11)),
                ),
                const SizedBox(width: 6),
                TextButton(
                  onPressed: widget.onStoreTap,
                  style: TextButton.styleFrom(
                    foregroundColor: fg,
                    backgroundColor: fg.withValues(alpha: 0.18),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                  ),
                  child: const AppText('زيارة المتجر',
                      style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          // بطاقات المنتجات (5 على الأقل)
          SizedBox(
            // صورة مربعة 150 + سطرا الاسم + التقييم + السعر + السعر القديم
            height: 285,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              itemCount: d.products.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) => _ProductCard(
                product: d.products[i],
                onTap: () => widget.onProductTap(d.products[i]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductCard extends StatelessWidget {
  final ShowcaseProduct product;
  final VoidCallback onTap;
  const _ProductCard({required this.product, required this.onTap});

  String _fmt(double v) => '${v.toStringAsFixed(0)} ل.س';

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final discount =
        (product.oldPrice != null && product.oldPrice! > product.price)
            ? ((1 - product.price / product.oldPrice!) * 100).round()
            : null;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        decoration: BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: 1,
                  child: ShowcaseCardImages(
                      key: ValueKey('showcase-images-${product.id}'),
                      urls: product.images),
                ),
                if (discount != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                          color: AppColors.sale,
                          borderRadius: BorderRadius.circular(8)),
                      child: AppText('-$discount%',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(product.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12.5, height: 1.3)),
                  const SizedBox(height: 3),
                  if (product.rating != null)
                    Row(children: [
                      const Icon(Icons.star_rounded,
                          size: 14, color: AppColors.gold),
                      const SizedBox(width: 2),
                      AppText(product.rating!.toStringAsFixed(1),
                          style: const TextStyle(
                              fontSize: 11, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 3),
                      AppText('(${product.reviewsCount})',
                          style: TextStyle(
                              fontSize: 11, color: context.mutedText)),
                    ]),
                  const SizedBox(height: 3),
                  AppText(_fmt(product.price),
                      style: const TextStyle(
                          fontSize: 14, fontWeight: FontWeight.bold)),
                  if (product.oldPrice != null &&
                      product.oldPrice! > product.price)
                    AppText(_fmt(product.oldPrice!),
                        style: TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: context.mutedText)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// صور بطاقة العرض: تتقلّب كل 2.2 ثانية مثل بطاقة الويب، تتوقف عند السحب
/// اليدوي ثم تستأنف، وتحترم إعداد "تقليل الحركة" في الجهاز.
class ShowcaseCardImages extends StatefulWidget {
  const ShowcaseCardImages({super.key, required this.urls});

  final List<String> urls;

  static const interval = Duration(milliseconds: 2200);

  @override
  State<ShowcaseCardImages> createState() => _ShowcaseCardImagesState();
}

class _ShowcaseCardImagesState extends State<ShowcaseCardImages> {
  final _controller = PageController();
  Timer? _timer;
  int _index = 0;

  bool get _canAnimate =>
      widget.urls.length > 1 &&
      !(MediaQuery.maybeOf(context)?.disableAnimations ?? false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _schedule());
  }

  void _schedule([Duration delay = ShowcaseCardImages.interval]) {
    _timer?.cancel();
    if (!mounted || !_canAnimate) return;
    _timer = Timer(delay, _next);
  }

  void _next() {
    if (!mounted || !_controller.hasClients || !_canAnimate) return;
    _controller.animateToPage((_index + 1) % widget.urls.length,
        duration: const Duration(milliseconds: 320), curve: Curves.easeInOut);
    _schedule();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Widget _placeholder(IconData icon) => ColoredBox(
        color: context.mutedSurface,
        child: Center(child: Icon(icon, color: context.mutedText)),
      );

  @override
  Widget build(BuildContext context) {
    final urls = widget.urls;
    if (urls.isEmpty) return _placeholder(Icons.image_not_supported_outlined);

    Widget image(String url) => CachedNetworkImage(
          imageUrl: url,
          fit: BoxFit.cover,
          placeholder: (_, __) => ColoredBox(color: context.mutedSurface),
          errorWidget: (_, __, ___) => _placeholder(Icons.broken_image_outlined),
        );

    if (urls.length == 1) return image(urls.first);

    return Stack(
      fit: StackFit.expand,
      children: [
        NotificationListener<ScrollStartNotification>(
          onNotification: (n) {
            // سحب يدوي: أوقف التقليب ثم استأنف بعد مهلة أطول
            if (n.dragDetails != null) _schedule(const Duration(milliseconds: 3200));
            return false;
          },
          child: PageView.builder(
            controller: _controller,
            itemCount: urls.length,
            onPageChanged: (i) => setState(() => _index = i),
            itemBuilder: (_, i) => image(urls[i]),
          ),
        ),
        PositionedDirectional(
          start: 0,
          end: 0,
          bottom: 6,
          child: IgnorePointer(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < urls.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    width: i == _index ? 14 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _index
                          ? AppColors.brandGreen
                          : AppColors.brandGreen.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// تباين الألوان (للمعاينة الحية عند البائع). يطابق حساب السيرفر.
class ColorContrast {
  static double _lum(String hex) {
    double f(int v) {
      final c = v / 255;
      return c <= 0.03928
          ? c / 12.92
          : math.pow((c + 0.055) / 1.055, 2.4).toDouble();
    }

    final h = hex.replaceFirst('#', '');
    final r = int.parse(h.substring(0, 2), radix: 16);
    final g = int.parse(h.substring(2, 4), radix: 16);
    final b = int.parse(h.substring(4, 6), radix: 16);
    return 0.2126 * f(r) + 0.7152 * f(g) + 0.0722 * f(b);
  }

  static double ratio(String a, String b) {
    final l1 = _lum(a), l2 = _lum(b);
    final hi = math.max(l1, l2), lo = math.min(l1, l2);
    return (hi + 0.05) / (lo + 0.05);
  }

  /// يعيد (isLightText, minRatio). المقبول: minRatio >= 3.0
  static (bool, double) pick(List<String> colors) {
    double minFor(String text) =>
        colors.map((c) => ratio(text, c)).reduce(math.min);
    final light = minFor('#FFFFFF');
    final dark = minFor('#111111');
    return light >= dark ? (true, light) : (false, dark);
  }
}

/// ألوان جاهزة يختار منها البائع (يمكنه أيضاً تركيب تدرج من 2 إلى 3 ألوان من لوحة ألوان).
const kGradientPresets = <(String, List<String>)>[
  ('غروب', ['#F46B45', '#EEA849']),
  ('محيط', ['#2193B0', '#6DD5ED']),
  ('غابة', ['#0F3D2E', '#2E7D5B']),
  ('ذهب أخضر', ['#0F3D2E', '#9A7425']),
  ('ليل', ['#141E30', '#243B55']),
  ('وردي', ['#B24592', '#F15F79']),
  ('بنفسجي', ['#4A00E0', '#8E2DE2']),
  ('نعناع', ['#00B09B', '#96C93D']),
  ('عنابي', ['#780206', '#061161']),
  ('رمل', ['#C79081', '#DFA579']),
  ('ثلاثي دافئ', ['#FF512F', '#F09819', '#FFD200']),
  ('ثلاثي بارد', ['#1A2980', '#1F6F8B', '#2A8C7C']),
];

/// حالات حجز مساحة العرض كما يرسلها السيرفر.
const kShowcaseStatusLabels = <String, String>{
  'pending_review': 'قيد المراجعة',
  'approved': 'معتمد',
  'rejected': 'مرفوض',
  'cancelled': 'ملغي',
  'expired': 'منتهي',
};
