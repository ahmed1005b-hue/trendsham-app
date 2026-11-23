import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_review_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/text_prompt_dialog.dart';

/// مراجعة كوبونات البائعين (نفس صفحة الموقع): الموافقة أو الرفض لما ينتظر المراجعة،
/// وإيقاف كوبون يعمل، مع سبب يصل للبائع.
class AdminSellerCouponsScreen extends StatefulWidget {
  const AdminSellerCouponsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminReviewService? service;

  @override
  State<AdminSellerCouponsScreen> createState() =>
      _AdminSellerCouponsScreenState();
}

class _AdminSellerCouponsScreenState extends State<AdminSellerCouponsScreen> {
  late final AdminReviewService _service =
      widget.service ?? AdminReviewService();
  String? _status;
  SellerCouponsPage? _page;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final page = await _service.sellerCoupons(status: _status);
      if (mounted) setState(() => _page = page);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل كوبونات البائعين.');
    }
  }

  Future<String?> _askReason(String title) => showTextPrompt(context,
      title: title,
      label: 'السبب (يصل للبائع)',
      required: true,
      emptyError: 'اكتب السبب ليصل للبائع.',
      maxLength: 500,
      maxLines: 3,
      fieldKey: const ValueKey('coupon-reason'),
      sendKey: const ValueKey('coupon-reason-send'));

  Future<void> _act(SellerCouponReview c, String action) async {
    String? reason;
    if (action == 'reject') {
      reason = await _askReason('رفض الكوبون');
      if (reason == null) return;
    } else if (action == 'suspend') {
      reason = await _askReason('إيقاف الكوبون');
      if (reason == null) return;
    }
    setState(() => _busy = true);
    try {
      final message = await _service.reviewCoupon(c.id, action, reason: reason);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: AppText('تعذّر الاتصال بالسيرفر.')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('كوبونات البائعين')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : page == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      if (page.pendingCount > 0)
                        Card(
                          color: const Color(0xFFFFF4E0),
                          child: ListTile(
                            leading: const Icon(Icons.hourglass_top,
                                color: Color(0xFFC9962C)),
                            title: Row(children: [
                              const AppText('بانتظار موافقة الإدارة'),
                              Text(': ${page.pendingCount}'),
                            ]),
                          ),
                        ),
                      DropdownButtonFormField<String?>(
                        key: const ValueKey('coupon-status-filter'),
                        initialValue: _status,
                        decoration:
                            InputDecoration(labelText: context.tr('الحالة')),
                        items: [
                          const DropdownMenuItem(
                              value: null, child: AppText('الكل')),
                          for (final (value, label) in page.statuses)
                            DropdownMenuItem(
                                value: value, child: AppText(label)),
                        ],
                        onChanged: (v) {
                          setState(() => _status = v);
                          _load();
                        },
                      ),
                      const SizedBox(height: 8),
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 40),
                          child: AppStateMessage(
                              message: 'لا توجد كوبونات هنا.',
                              icon: Icons.confirmation_number_outlined),
                        ),
                      for (final c in page.items) _couponCard(c),
                    ],
                  ),
                ),
    );
  }

  Widget _couponCard(SellerCouponReview c) {
    return Card(
      key: ValueKey('seller-coupon-${c.id}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(c.title,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              Chip(
                label: AppText(c.statusLabel ?? c.status,
                    style: const TextStyle(fontSize: 11)),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            if (c.storeName != null)
              Text(c.storeName!,
                  style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 4),
            Wrap(spacing: 12, children: [
              if (c.valueLabel != null)
                AppText(c.valueLabel!,
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, color: AppColors.emerald)),
              if (c.audienceLabel != null)
                AppText(c.audienceLabel!, style: const TextStyle(fontSize: 12)),
              if (c.giftProduct != null)
                Text('🎁 ${c.giftProduct}',
                    style: const TextStyle(fontSize: 12)),
              if (c.endsAt != null)
                Text(DateFormat('yyyy-MM-dd').format(c.endsAt!.toLocal()),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
            ]),
            if ((c.reviewNote ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(c.reviewNote!,
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            if (c.isPending || c.canSuspend)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(spacing: 8, children: [
                  if (c.isPending) ...[
                    FilledButton(
                      key: ValueKey('coupon-approve-${c.id}'),
                      onPressed: _busy ? null : () => _act(c, 'approve'),
                      child: const AppText('موافقة'),
                    ),
                    OutlinedButton(
                      key: ValueKey('coupon-reject-${c.id}'),
                      onPressed: _busy ? null : () => _act(c, 'reject'),
                      child: const AppText('رفض',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                  if (c.canSuspend)
                    OutlinedButton(
                      key: ValueKey('coupon-suspend-${c.id}'),
                      onPressed: _busy ? null : () => _act(c, 'suspend'),
                      child: const AppText('إيقاف',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                ]),
              ),
          ],
        ),
      ),
    );
  }
}
