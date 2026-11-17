import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/api_config.dart';
import '../config/theme.dart';
import '../l10n/app_localizations.dart';
import '../models/coupon_story.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/store/store_screen.dart';

/// يفتح عارض القصص الموحّد (نفس شكل الموقع: بطاقة 9:16 والصورة تملؤها).
Future<void> showStoryViewer(
  BuildContext context, {
  required List<StoryModel> stories,
  int initialIndex = 0,
}) {
  if (stories.isEmpty) return Future.value();
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (_) => StoryViewer(stories: stories, initialIndex: initialIndex),
  );
}

class StoryViewer extends StatefulWidget {
  const StoryViewer({
    super.key,
    required this.stories,
    this.initialIndex = 0,
  });

  final List<StoryModel> stories;
  final int initialIndex;

  static const storyDuration = Duration(seconds: 10);

  /// رابط داخل الموقع نفسه ← شاشة داخل التطبيق بدل المتصفح.
  /// يعيد null إن لم يكن رابط منتج أو متجر من موقعنا.
  static Widget? inAppTarget(Uri uri) {
    final site = Uri.tryParse(ApiConfig.storageBaseUrl);
    if (site == null || uri.host != site.host) return null;
    final base = site.pathSegments.where((s) => s.isNotEmpty).toList();
    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final rest = segments.length >= base.length &&
            List.generate(base.length, (i) => segments[i] == base[i])
                .every((same) => same)
        ? segments.sublist(base.length)
        : segments;
    if (rest.length != 2) return null;
    if (rest[0] == 'product') return ProductDetailScreen(slug: rest[1]);
    final storeId = int.tryParse(rest[1]);
    if (rest[0] == 'store' && storeId != null) {
      return StoreScreen(storeId: storeId);
    }
    return null;
  }

  @override
  State<StoryViewer> createState() => _StoryViewerState();
}

class _StoryViewerState extends State<StoryViewer>
    with SingleTickerProviderStateMixin {
  late int _index;
  late final AnimationController _progress;

  StoryModel get _story => widget.stories[_index];

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex.clamp(0, widget.stories.length - 1);
    _progress = AnimationController(
      vsync: this,
      duration: StoryViewer.storyDuration,
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _go(1);
      });
    _progress.forward();
  }

  @override
  void dispose() {
    _progress.dispose();
    super.dispose();
  }

  void _go(int step) {
    final next = _index + step;
    if (next >= widget.stories.length) {
      Navigator.of(context).maybePop();
      return;
    }
    setState(() => _index = next < 0 ? 0 : next);
    _progress.forward(from: 0);
  }

  Future<void> _openLink() async {
    final link = _story.linkUrl;
    final uri = link == null ? null : Uri.tryParse(link);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https')) {
      return;
    }
    _progress.stop();
    final target = StoryViewer.inAppTarget(uri);
    final navigator = Navigator.of(context);
    navigator.pop();
    if (target != null) {
      await navigator.push(MaterialPageRoute(builder: (_) => target));
    } else {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final story = _story;
    final name = story.vendorName ?? 'تريند شام';
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final size = MediaQuery.sizeOf(context);
    // أكبر بطاقة 9:16 تتسع في الشاشة
    final width = [size.width - 24, (size.height - 48) * 9 / 16, 420.0]
        .reduce((a, b) => a < b ? a : b);

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 9 / 16,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: GestureDetector(
              onLongPressStart: (_) => _progress.stop(),
              onLongPressEnd: (_) => _progress.forward(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  const ColoredBox(color: Color(0xFF111111)),
                  CachedNetworkImage(
                    key: ValueKey(story.id),
                    imageUrl: story.imageUrl,
                    fit: BoxFit.cover,
                    placeholder: (_, __) => const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    ),
                    errorWidget: (_, __, ___) => const Center(
                      child: Icon(Icons.broken_image,
                          color: Colors.white54, size: 48),
                    ),
                  ),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Color(0x73000000),
                          Colors.transparent,
                          Colors.transparent,
                          Color(0xBF000000),
                        ],
                        stops: [0, .22, .58, 1],
                      ),
                    ),
                  ),
                  // مناطق اللمس: البداية = السابق، النهاية = التالي
                  Positioned.fill(
                    top: 70,
                    bottom: 110,
                    child: Row(
                      children: [
                        Expanded(
                          flex: 2,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _go(-1),
                          ),
                        ),
                        Expanded(
                          flex: 3,
                          child: GestureDetector(
                            behavior: HitTestBehavior.translucent,
                            onTap: () => _go(1),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    top: 10,
                    left: 10,
                    right: 10,
                    child: AnimatedBuilder(
                      animation: _progress,
                      builder: (context, _) => Row(
                        textDirection:
                            isRtl ? TextDirection.rtl : TextDirection.ltr,
                        children: [
                          for (var i = 0; i < widget.stories.length; i++)
                            Expanded(
                              child: Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(3),
                                  child: LinearProgressIndicator(
                                    value: i < _index
                                        ? 1
                                        : i == _index
                                            ? _progress.value
                                            : 0,
                                    minHeight: 3,
                                    backgroundColor: Colors.white38,
                                    valueColor:
                                        const AlwaysStoppedAnimation<Color>(
                                            Colors.white),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 22,
                    left: 10,
                    right: 10,
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 17,
                          backgroundColor: AppColors.brandGreen,
                          backgroundImage: story.vendorLogoUrl != null
                              ? CachedNetworkImageProvider(story.vendorLogoUrl!)
                              : null,
                          child: story.vendorLogoUrl == null
                              ? Text(
                                  name.characters.isEmpty
                                      ? ''
                                      : name.characters.first,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(width: 8),
                        Flexible(
                          child: Text(
                            name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              shadows: [
                                Shadow(blurRadius: 3, color: Colors.black54)
                              ],
                            ),
                          ),
                        ),
                        if (story.isFromPlatform) ...[
                          const SizedBox(width: 4),
                          const Icon(Icons.verified,
                              size: 15, color: Color(0xFFE9C46A)),
                        ],
                        const Spacer(),
                        IconButton(
                          tooltip: context.tr('إغلاق'),
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.black26,
                          ),
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 16,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (story.caption != null && story.caption!.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: AppText(
                              story.caption!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                height: 1.4,
                                shadows: [
                                  Shadow(blurRadius: 4, color: Colors.black87)
                                ],
                              ),
                            ),
                          ),
                        if (story.hasLink)
                          FilledButton.icon(
                            key: const ValueKey('story-link'),
                            onPressed: _openLink,
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: Colors.black87,
                              minimumSize: const Size(160, 46),
                              shape: const StadiumBorder(),
                            ),
                            icon: const Icon(Icons.link),
                            label: const AppText(
                              'اكتشف الآن',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
