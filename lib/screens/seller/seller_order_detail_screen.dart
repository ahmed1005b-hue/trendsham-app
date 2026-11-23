import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../models/seller_parcel.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../widgets/app_state_message.dart';
import 'parcel_actions.dart';

/// تفاصيل طلب للبائع (نفس صفحة الطلب في لوحة البائع بالموقع):
/// طرده وطريقة توصيله، والمبلغ الذي يحصّله، وبيانات الزبون، ومنتجاته في الطلب.
class SellerOrderDetailScreen extends StatefulWidget {
  const SellerOrderDetailScreen(
      {super.key, required this.orderId, this.service});

  final int orderId;

  /// للاختبار: خدمة بديلة بلا شبكة
  final SellerService? service;

  @override
  State<SellerOrderDetailScreen> createState() =>
      _SellerOrderDetailScreenState();
}

class _SellerOrderDetailScreenState extends State<SellerOrderDetailScreen> {
  late final SellerService _service = widget.service ?? SellerService();
  final _money = NumberFormat.decimalPattern('en');
  Order? _order;
  SellerParcel? _parcel;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final (order, parcel) = await _service.orderDetail(widget.orderId);
      if (mounted) {
        setState(() {
          _order = order;
          _parcel = parcel;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الطلب.');
    }
  }

  Future<void> _changeStatus(String status) async {
    if (await changeParcelStatus(context, _service, widget.orderId, status)) {
      await _load();
    }
  }

  String _price(double v) => '${_money.format(v)} ل.س';

  @override
  Widget build(BuildContext context) {
    final order = _order;
    final parcel = _parcel;
    return Scaffold(
      appBar: AppBar(
        title: Row(children: [
          const AppText('رقم الطلب'),
          const SizedBox(width: 6),
          if (order != null)
            Text(order.orderNumber, textDirection: TextDirection.ltr),
        ]),
      ),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : order == null || parcel == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.emerald,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                    children: [
                      _parcelCard(order, parcel),
                      _customerCard(order, parcel),
                      _itemsCard(order),
                      _actions(parcel),
                    ],
                  ),
                ),
    );
  }

  Widget _parcelCard(Order order, SellerParcel p) {
    final icon = p.isPickup
        ? Icons.storefront_outlined
        : (p.deliveryMode == 'self'
            ? Icons.delivery_dining_outlined
            : Icons.local_shipping_outlined);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const AppText('حالة طردك',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
              const Spacer(),
              Chip(
                key: const ValueKey('parcel-status'),
                label: AppText(p.statusLabel ??
                    Shipment.statusLabels[p.status] ??
                    p.status),
                visualDensity: VisualDensity.compact,
              ),
            ]),
            Row(children: [
              Icon(icon, size: 18, color: AppColors.emerald),
              const SizedBox(width: 6),
              Expanded(child: AppText(p.deliveryModeLabel ?? '')),
            ]),
            if (p.sellerDelivers && p.codAmount > 0)
              Container(
                key: const ValueKey('parcel-cod'),
                width: double.infinity,
                margin: const EdgeInsets.only(top: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF4E0),
                  border: Border.all(color: const Color(0xFFC9962C)),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(p.isPickup
                        ? 'حصّل من الزبون عند استلامه من محلك:'
                        : 'حصّل من الزبون عند التسليم:'),
                    AppText(_price(p.codAmount),
                        style: const TextStyle(
                            fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
              )
            else if (p.sellerDelivers && order.isPaid)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: AppText('الطلب مدفوع مسبقاً، لا تحصّل شيئاً من الزبون.',
                    style: TextStyle(color: AppColors.emerald)),
              ),
            if (p.isShared)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: AppText(
                    'في الطلب منتجات من متاجر أخرى؛ أنت تدير طردك فقط.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
            if ((p.trackingNumber ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  const AppText('رقم التتبع:', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 4),
                  Text(p.trackingNumber!,
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(fontSize: 12)),
                ]),
              ),
            if (order.createdAt != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                    DateFormat('yyyy-MM-dd HH:mm')
                        .format(order.createdAt!.toLocal()),
                    style:
                        const TextStyle(fontSize: 12, color: AppColors.muted)),
              ),
          ],
        ),
      ),
    );
  }

  Widget _customerCard(Order order, SellerParcel p) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('بيانات الزبون',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(order.shippingName,
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            Text(order.shippingPhone, textDirection: TextDirection.ltr),
            if (p.isPickup)
              const AppText('يستلمه الزبون من المحل',
                  style: TextStyle(fontWeight: FontWeight.bold))
            else ...[
              if ((p.governorate ?? '').isNotEmpty)
                AppText(p.governorate!,
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              Text(order.shippingAddress),
            ],
          ],
        ),
      ),
    );
  }

  Widget _itemsCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('محتويات الطرد',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final item in order.items)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Expanded(child: Text(item.displayName)),
                  Text('× ${item.quantity}',
                      textDirection: TextDirection.ltr,
                      style: const TextStyle(color: AppColors.muted)),
                  const SizedBox(width: 12),
                  AppText(_price(item.subtotal),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                ]),
              ),
          ],
        ),
      ),
    );
  }

  Widget _actions(SellerParcel p) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (p.canPrintLabel)
            FilledButton.icon(
              key: const ValueKey('detail-parcel-label'),
              onPressed: () => printParcelLabel(
                  context, _service, widget.orderId, _order?.orderNumber),
              icon: const Icon(Icons.print_outlined),
              label: const AppText('طباعة ملصق الشحنة'),
            ),
          const SizedBox(height: 8),
          if (p.nextStatuses.isEmpty)
            const AppText('لا توجد خطوة تالية لطردك.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.muted))
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final s in p.nextStatuses)
                  OutlinedButton(
                    key: ValueKey('detail-status-$s'),
                    style: s == 'cancelled'
                        ? OutlinedButton.styleFrom(
                            foregroundColor: AppColors.danger)
                        : null,
                    onPressed: () => _changeStatus(s),
                    child: AppText(
                        Shipment.statusLabels[s] ?? Order.statusLabels[s] ?? s),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
