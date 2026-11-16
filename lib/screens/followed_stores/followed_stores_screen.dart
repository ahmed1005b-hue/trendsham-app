import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/vendor.dart';
import '../../services/api_exception.dart';
import '../../services/store_service.dart';
import '../store/store_screen.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

class FollowedStoresScreen extends StatefulWidget {
  const FollowedStoresScreen({super.key, this.service});

  /// قابل للاستبدال في الاختبارات.
  final StoreService? service;

  @override
  State<FollowedStoresScreen> createState() => _FollowedStoresScreenState();
}

class _FollowedStoresScreenState extends State<FollowedStoresScreen> {
  late final StoreService _service = widget.service ?? StoreService();
  final Set<int> _busy = {};
  final List<Vendor> _stores = [];
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _page = 1;
  int _lastPage = 1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load({bool refresh = false}) async {
    if (refresh) {
      setState(() {
        _page = 1;
        _lastPage = 1;
        _stores.clear();
        _error = null;
        _loading = true;
      });
    }
    try {
      final result = await _service.followedStores(page: _page);
      if (!mounted) return;
      setState(() {
        _stores
          ..clear()
          ..addAll(result.stores);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'تعذر تحميل المتاجر المتابعة.';
      });
    }
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _page >= _lastPage) return;
    setState(() => _loadingMore = true);
    try {
      final result = await _service.followedStores(page: _page + 1);
      if (!mounted) return;
      setState(() {
        _stores.addAll(result.stores);
        _page = result.currentPage;
        _lastPage = result.lastPage;
        _loadingMore = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingMore = false);
    }
  }

  Future<void> _unfollow(Vendor store) async {
    if (_busy.contains(store.id)) return;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('إلغاء المتابعة'),
        content: AppText('لن تصلك تحديثات وعروض «${store.storeName}» بعد الآن.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('تراجع'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: const AppText('إلغاء المتابعة'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    setState(() => _busy.add(store.id));
    String message;
    try {
      // التبديل يعيد الحالة الجديدة: لا نحذف المتجر إن عاد متابَعاً (أُلغي من مكان آخر)
      final stillFollowed = await _service.toggleFollow(store.id);
      if (!mounted) return;
      if (stillFollowed) {
        await _load(refresh: true);
        message = 'تغيّرت حالة المتابعة، تم تحديث القائمة.';
      } else {
        setState(() => _stores.removeWhere((s) => s.id == store.id));
        message = 'تم إلغاء متابعة المتجر.';
      }
    } on ApiException catch (e) {
      message = e.message;
    } catch (_) {
      message = 'تعذّر إلغاء المتابعة. تحقق من الاتصال وحاول مجدداً.';
    }
    if (!mounted) return;
    setState(() => _busy.remove(store.id));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.isDarkTheme ? null : const Color(0xFFF4F5F7),
      appBar: AppBar(
        elevation: 0,
        title: const AppText('المتاجر التي أتابعها',
            style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const ListSkeleton(circleLeading: true);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppText(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: () => _load(refresh: true),
                child: const AppText('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (_stores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.storefront_outlined,
                  size: 56, color: context.mutedText),
              const SizedBox(height: 10),
              const AppText('لا تتابع أي متجر حالياً.',
                  style: TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              AppText('اضغط «متابعة» في صفحة أي متجر لتصلك عروضه ومنتجاته الجديدة.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: context.mutedText)),
            ],
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(refresh: true),
      child: ListView.separated(
        padding: const EdgeInsets.all(14),
        itemCount: _stores.length + (_page < _lastPage ? 1 : 0),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (context, index) {
          if (index >= _stores.length) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _loadMore();
            });
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()),
            );
          }
          return _storeCard(_stores[index]);
        },
      ),
    );
  }

  Widget _storeCard(Vendor store) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => StoreScreen(storeId: store.id)),
        );
        if (mounted) _load(refresh: true);
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: SizedBox(
                width: 56,
                height: 56,
                child: (store.storeLogo ?? '').isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: store.storeLogo!,
                        fit: BoxFit.cover,
                        errorWidget: (_, __, ___) => _logoFallback(),
                        placeholder: (_, __) => _logoFallback(),
                      )
                    : _logoFallback(),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                    store.storeName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 3),
                  Wrap(
                    spacing: 10,
                    runSpacing: 2,
                    children: [
                      AppText('${store.productsCount ?? 0} منتج',
                          style: TextStyle(
                              fontSize: 12, color: context.mutedText)),
                      AppText('${store.followersCount} متابع',
                          style: TextStyle(
                              fontSize: 12, color: context.mutedText)),
                      if (store.sellerRating != null)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.star_rounded,
                                size: 14, color: Color(0xFFF2994A)),
                            const SizedBox(width: 2),
                            AppText(store.sellerRating!.toStringAsFixed(1),
                                style: TextStyle(
                                    fontSize: 12, color: context.mutedText)),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton(
              onPressed: _busy.contains(store.id) ? null : () => _unfollow(store),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.danger,
                side: const BorderSide(color: Color(0xFFF2C7C7)),
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                minimumSize: const Size(0, 36),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const AppText('إلغاء المتابعة', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _logoFallback() => Container(
        color: context.mutedSurface,
        child:
            const Icon(Icons.storefront_outlined, color: AppColors.brandGreen),
      );
}
