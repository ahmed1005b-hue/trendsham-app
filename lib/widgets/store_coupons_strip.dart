import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/app_localizations.dart';
import '../models/store_coupon.dart';
import '../providers/auth_provider.dart';
import '../services/api_exception.dart';
import '../services/store_coupon_service.dart';
import '../utils/auth_prompt.dart';

/// شريط "كوبونات المتجر" مع زر احفظ.
class StoreCouponsStrip extends StatefulWidget {
  const StoreCouponsStrip({super.key, required this.coupons, this.service});

  final List<StoreCoupon> coupons;
  final StoreCouponService? service;

  @override
  State<StoreCouponsStrip> createState() => _StoreCouponsStripState();
}

class _StoreCouponsStripState extends State<StoreCouponsStrip> {
  late List<StoreCoupon> _coupons = widget.coupons;
  final Set<int> _busy = {};
  late final StoreCouponService _service = widget.service ?? StoreCouponService();

  static const _green = Color(0xFF0B5F4A);
  static const _gold = Color(0xFFC9962C);

  @override
  void didUpdateWidget(covariant StoreCouponsStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.coupons != widget.coupons) _coupons = widget.coupons;
  }

  Future<void> _collect(StoreCoupon c) async {
    if (context.read<AuthProvider>().user == null) {
      await showAuthRequiredDialog(context);
      return;
    }
    setState(() => _busy.add(c.id));
    final messenger = ScaffoldMessenger.of(context);
    try {
      final msg = await _service.collect(c.id);
      if (!mounted) return;
      setState(() => _replace(c.copyWith(state: 'collected', remaining: c.remaining > 0 ? c.remaining - 1 : 0)));
      messenger.showSnackBar(SnackBar(content: AppText(msg)));
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 409) setState(() => _replace(c.copyWith(state: 'collected')));
      if (e.statusCode == 410) setState(() => _replace(c.copyWith(state: 'sold_out', remaining: 0)));
      messenger.showSnackBar(SnackBar(content: AppText(e.message)));
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: AppText('تعذّر حفظ الكوبون، حاول مجدداً.')));
    } finally {
      if (mounted) setState(() => _busy.remove(c.id));
    }
  }

  void _replace(StoreCoupon c) {
    _coupons = [for (final x in _coupons) x.id == c.id ? c : x];
  }

  @override
  Widget build(BuildContext context) {
    if (_coupons.isEmpty) return const SizedBox.shrink();
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              Icon(Icons.confirmation_number_outlined, color: _gold, size: 20),
              SizedBox(width: 6),
              AppText('كوبونات المتجر', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _coupons.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (context, i) => _card(_coupons[i], dark),
            ),
          ),
        ],
      ),
    );
  }

  Widget _card(StoreCoupon c, bool dark) {
    final busy = _busy.contains(c.id);
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: dark ? const Color(0x22C9962C) : const Color(0xFFFFFBF0),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0x66C9962C)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(children: [
        Container(
          width: 84,
          color: _green,
          alignment: Alignment.center,
          padding: const EdgeInsets.all(6),
          child: AppText(c.shortValue,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFFF1D9A0), fontWeight: FontWeight.w800, fontSize: 15)),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppText(c.title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                AppText(c.scopeLabel, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A55))),
                if (c.endsAt != null)
                  AppText('حتى ${c.endsAt} · باقي ${c.remaining}', style: const TextStyle(fontSize: 11, color: Color(0xFF8A7A55))),
                _action(c, busy),
              ],
            ),
          ),
        ),
      ]),
    );
  }

  Widget _action(StoreCoupon c, bool busy) {
    switch (c.state) {
      case 'collected':
        return const Row(children: [
          Icon(Icons.check_circle, color: _green, size: 16),
          SizedBox(width: 4),
          AppText('محفوظ', style: TextStyle(color: _green, fontWeight: FontWeight.bold, fontSize: 12)),
        ]);
      case 'sold_out':
        return const AppText('نفدت', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12));
      default:
        return SizedBox(
          height: 28,
          child: FilledButton(
            style: FilledButton.styleFrom(backgroundColor: _green, padding: const EdgeInsets.symmetric(horizontal: 14)),
            onPressed: busy ? null : () => _collect(c),
            child: busy
                ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const AppText('احفظ', style: TextStyle(fontSize: 12)),
          ),
        );
    }
  }
}
