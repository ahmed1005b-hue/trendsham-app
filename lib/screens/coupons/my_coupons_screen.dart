import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../models/wallet_coupon.dart';
import '../../services/api_exception.dart';
import '../../services/checkout_service.dart';
import '../../widgets/coupon_tile.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

/// "كوبوناتي": المتاحة، والمستخدمة، والمنتهية. لا رموز — نطبّق الأفضل تلقائياً عند الدفع.
class MyCouponsScreen extends StatefulWidget {
  const MyCouponsScreen({super.key});

  @override
  State<MyCouponsScreen> createState() => _MyCouponsScreenState();
}

class _MyCouponsScreenState extends State<MyCouponsScreen> {
  final _service = CouponService();

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('كوبوناتي'),
          bottom: const TabBar(tabs: [
            Tab(text: 'متاحة'),
            Tab(text: 'مستخدمة'),
            Tab(text: 'منتهية'),
          ]),
        ),
        body: TabBarView(children: [
          _CouponList(service: _service, tab: 'available'),
          _CouponList(service: _service, tab: 'used'),
          _CouponList(service: _service, tab: 'expired'),
        ]),
      ),
    );
  }
}

class _CouponList extends StatefulWidget {
  final CouponService service;
  final String tab;

  const _CouponList({required this.service, required this.tab});

  @override
  State<_CouponList> createState() => _CouponListState();
}

class _CouponListState extends State<_CouponList> {
  late Future<List<WalletCoupon>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.service.myCoupons(tab: widget.tab);
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.service.myCoupons(tab: widget.tab));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      color: AppColors.emerald,
      child: FutureBuilder<List<WalletCoupon>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const ListSkeleton(itemCount: 4, leadingSize: 48);
          }
          if (snap.hasError) {
            final msg = snap.error is ApiException
                ? (snap.error as ApiException).message
                : 'تعذّر تحميل الكوبونات.';
            return ListView(children: [
              Padding(
                  padding: const EdgeInsets.all(32),
                  child: AppText(msg, textAlign: TextAlign.center)),
            ]);
          }
          final items = snap.data ?? const [];
          if (items.isEmpty) {
            return ListView(children: [
              const SizedBox(height: 80),
              const Icon(Icons.confirmation_number_outlined,
                  size: 56, color: AppColors.muted),
              const SizedBox(height: 12),
              AppText(
                widget.tab == 'available'
                    ? 'لا توجد كوبونات متاحة حالياً.\nسنبلغك فور وصول كوبون جديد.'
                    : 'لا شيء هنا.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.muted),
              ),
            ]);
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => CouponTile(
              coupon: items[i],
              muted: widget.tab != 'available',
              note: widget.tab == 'used' && items[i].usedAt != null
                  ? 'استُخدم ${items[i].usedAt!.toLocal().toString().substring(0, 10)}'
                  : null,
            ),
          );
        },
      ),
    );
  }
}
