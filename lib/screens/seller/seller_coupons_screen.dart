import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/seller_coupon.dart';
import '../../services/api_exception.dart';
import '../../services/seller_coupon_service.dart';
import '../../widgets/app_state_message.dart';
import 'seller_coupon_form_screen.dart';

/// «كوبوناتي»: البائع ينشئ كوبونات لمتجره ويتحمّل خصمها من أرباحه.
class SellerCouponsScreen extends StatefulWidget {
  const SellerCouponsScreen({super.key, this.service});

  final SellerCouponService? service;

  @override
  State<SellerCouponsScreen> createState() => _SellerCouponsScreenState();
}

class _SellerCouponsScreenState extends State<SellerCouponsScreen> {
  late final SellerCouponService _service =
      widget.service ?? SellerCouponService();
  SellerCouponsPage? _page;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await _service.list();
      if (!mounted) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = context.tr('تعذّر تحميل الكوبونات.');
        _loading = false;
      });
    }
  }

  void _toast(String message) {
    if (!mounted || message.isEmpty) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _openForm([SellerCoupon? coupon]) async {
    final page = _page;
    if (page == null) return;
    final message = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => SellerCouponFormScreen(
          service: _service,
          page: page,
          coupon: coupon,
        ),
      ),
    );
    if (message != null) {
      _toast(message);
      _load();
    }
  }

  Future<void> _toggle(SellerCoupon coupon) async {
    try {
      final updated = await _service.toggle(coupon.id);
      if (!mounted) return;
      _toast(updated.status == 'paused'
          ? context.tr('أوقفت الكوبون مؤقتاً.')
          : context.tr('الكوبون يعمل من جديد.'));
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete(SellerCoupon coupon) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف الكوبون؟'),
        content: AppText(coupon.title),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(coupon.id);
      if (!mounted) return;
      _toast(context.tr('حُذف الكوبون.'));
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    final blocked = page?.blockReason;
    return Scaffold(
      appBar: AppBar(title: const AppText('كوبوناتي')),
      floatingActionButton: page == null || blocked != null
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('new-coupon'),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const AppText('كوبون جديد'),
            ),
      body: _loading && page == null
          ? const Center(child: CircularProgressIndicator())
          : _error != null && page == null
              ? AppStateMessage(
                  icon: Icons.error_outline,
                  message: _error!,
                  onRetry: _load,
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
                    children: [
                      _intro(context, page!),
                      if (blocked != null) _blockedBanner(blocked),
                      if (page.coupons.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 48),
                          child: AppStateMessage(
                            icon: Icons.confirmation_number_outlined,
                            message:
                                'لا توجد كوبونات بعد. أنشئ كوبوناً ليجمعه العملاء من صفحة متجرك.',
                          ),
                        ),
                      for (final coupon in page.coupons) _card(context, coupon),
                    ],
                  ),
                ),
    );
  }

  Widget _intro(BuildContext context, SellerCouponsPage page) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: AppText(
          context
              .tr('الخصم يُخصم من أرباحك. الخصم فوق :p% ينتظر موافقة الإدارة.')
              .replaceAll(':p', '${page.reviewAbovePercent}'),
          style: const TextStyle(fontSize: 12, color: AppColors.muted),
        ),
      );

  Widget _blockedBanner(String reason) => Container(
        key: const ValueKey('coupon-blocked'),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.lock_outline, color: Colors.orange),
            const SizedBox(width: 8),
            Expanded(child: AppText(reason)),
          ],
        ),
      );

  Color _statusColor(String status) => switch (status) {
        'active' => Colors.green,
        'pending_review' => Colors.orange,
        'paused' => Colors.blueGrey,
        _ => Colors.red,
      };

  String _date(DateTime? d) => d == null
      ? '—'
      : '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _card(BuildContext context, SellerCoupon coupon) {
    final color = _statusColor(coupon.status);
    return Card(
      key: ValueKey('coupon-${coupon.id}'),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: context.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.confirmation_number_outlined,
                    color: AppColors.brandGreen),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    coupon.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    coupon.statusLabel,
                    style: TextStyle(
                        color: color,
                        fontSize: 11,
                        fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              coupon.valueLabel,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                color: AppColors.brandGreen,
              ),
            ),
            const SizedBox(height: 6),
            AppText(
              context
                  .tr('جُمع :issued من :total · استُخدم :used')
                  .replaceAll(':issued', '${coupon.issuedCount}')
                  .replaceAll(':total', '${coupon.totalLimit ?? '∞'}')
                  .replaceAll(':used', '${coupon.redeemedCount}'),
              style: const TextStyle(fontSize: 12),
            ),
            const SizedBox(height: 4),
            AppText(
              context
                  .tr('ينتهي :date')
                  .replaceAll(':date', _date(coupon.endsAt)),
              style: const TextStyle(fontSize: 12, color: AppColors.muted),
            ),
            if (coupon.reviewNote != null &&
                coupon.reviewNote!.isNotEmpty &&
                (coupon.status == 'rejected' || coupon.status == 'suspended'))
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  coupon.reviewNote!,
                  style: const TextStyle(fontSize: 12, color: Colors.red),
                ),
              ),
            const Divider(height: 20),
            Wrap(
              spacing: 4,
              children: [
                if (coupon.canEdit)
                  TextButton.icon(
                    key: ValueKey('edit-${coupon.id}'),
                    onPressed: () => _openForm(coupon),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: AppText(coupon.isLocked ? 'تمديد' : 'تعديل'),
                  ),
                if (coupon.canToggle)
                  TextButton.icon(
                    key: ValueKey('toggle-${coupon.id}'),
                    onPressed: () => _toggle(coupon),
                    icon: Icon(
                      coupon.status == 'active'
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 18,
                    ),
                    label: AppText(
                        coupon.status == 'active' ? 'إيقاف مؤقت' : 'تشغيل'),
                  ),
                if (coupon.canDelete)
                  TextButton.icon(
                    key: ValueKey('delete-${coupon.id}'),
                    onPressed: () => _delete(coupon),
                    icon: const Icon(Icons.delete_outline,
                        size: 18, color: Colors.red),
                    label: const AppText('حذف',
                        style: TextStyle(color: Colors.red)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
