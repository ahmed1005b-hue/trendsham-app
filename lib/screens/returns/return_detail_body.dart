import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/return_request.dart';

String returnDate(DateTime? value) {
  if (value == null) return '';
  final d = value.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// محتوى تفاصيل طلب إرجاع (الحالة والسطور والمواعيد والاسترداد والسجل)
/// مشترك بين شاشة العميل وشاشة البائع؛ أزرار الإجراءات تأتي من [actions].
class ReturnDetailBody extends StatelessWidget {
  const ReturnDetailBody({
    super.key,
    required this.request,
    required this.onRefresh,
    this.actions = const [],
  });

  final ReturnRequest request;
  final Future<void> Function() onRefresh;
  final List<Widget> actions;

  Widget _card(String title, List<Widget> children) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AppText(title,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ...children,
            ],
          ),
        ),
      );

  Widget _row(String label, String value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(label),
            AppText(value,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.bold : FontWeight.normal)),
          ],
        ),
      );

  Widget _event(ReturnEvent e) => Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                  child: AppText(e.label,
                      style: const TextStyle(fontWeight: FontWeight.w600))),
              AppText(returnDate(e.createdAt),
                  style:
                      const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
            if (e.note != null && e.note!.isNotEmpty) AppText(e.note!),
            if (e.photos.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Wrap(spacing: 6, runSpacing: 6, children: [
                  for (final url in e.photos)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: CachedNetworkImage(
                          imageUrl: url,
                          width: 64,
                          height: 64,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => const SizedBox(
                              width: 64,
                              height: 64,
                              child: Icon(Icons.broken_image_outlined))),
                    ),
                ]),
              ),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final r = request;
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _card('الحالة', [
            Chip(label: AppText(r.statusLabel)),
            if (r.orderNumber != null) _row('الطلب', r.orderNumber!),
            if (r.storeName != null) _row('المتجر', r.storeName!),
            if (r.customerName != null) _row('العميل', r.customerName!),
            _row('السبب', r.reasonLabel),
            if (r.description != null && r.description!.isNotEmpty)
              AppText(r.description!,
                  style: const TextStyle(color: AppColors.muted)),
            if (r.decisionNote != null && r.decisionNote!.isNotEmpty) ...[
              const SizedBox(height: 6),
              AppText('ملاحظة القرار: ${r.decisionNote}'),
            ],
          ]),
          const SizedBox(height: 12),
          _card('المنتجات', [
            for (final item in r.items)
              _row(
                  '${item.productName}${item.variantLabel != null ? ' (${item.variantLabel})' : ''} × ${item.quantity}',
                  '${item.refundAmount.toStringAsFixed(0)} ل.س'),
            const Divider(),
            // refund_amount من السيرفر يشمل أجرة التوصيل؛ تُعرض للعلم فقط
            _row('مبلغ الاسترداد', '${r.refundAmount.toStringAsFixed(0)} ل.س',
                bold: true),
            if (r.shippingRefund > 0)
              _row('منها أجرة توصيل',
                  '${r.shippingRefund.toStringAsFixed(0)} ل.س'),
          ]),
          if (r.respondBy != null ||
              r.disputeBy != null ||
              r.shipBackBy != null) ...[
            const SizedBox(height: 12),
            _card('المواعيد', [
              if (r.respondBy != null)
                _row('مهلة رد البائع', returnDate(r.respondBy)),
              if (r.disputeBy != null)
                _row('آخر موعد للاعتراض', returnDate(r.disputeBy)),
              if (r.shipBackBy != null)
                _row('آخر موعد لإعادة الشحن', returnDate(r.shipBackBy)),
            ]),
          ],
          if (r.refund != null) ...[
            const SizedBox(height: 12),
            _card('الاسترداد', [
              _row('المبلغ', '${r.refund!.amount.toStringAsFixed(0)} ل.س',
                  bold: true),
              if (r.refund!.displayMethod != null)
                _row('الطريقة', r.refund!.displayMethod!),
              if (r.refund!.reference != null)
                _row('المرجع', r.refund!.reference!),
            ]),
          ],
          if (r.events.isNotEmpty) ...[
            const SizedBox(height: 12),
            _card('السجل', [for (final e in r.events) _event(e)]),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...actions,
          ],
        ],
      ),
    );
  }
}
