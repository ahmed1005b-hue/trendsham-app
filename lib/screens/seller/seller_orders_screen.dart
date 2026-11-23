import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import 'parcel_actions.dart';
import 'seller_order_detail_screen.dart';

class SellerOrdersScreen extends StatefulWidget {
  const SellerOrdersScreen({super.key});

  @override
  State<SellerOrdersScreen> createState() => _SellerOrdersScreenState();
}

class _SellerOrdersScreenState extends State<SellerOrdersScreen> {
  final SellerService _service = SellerService();
  List<OrderItem>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final items = await _service.orders();
      setState(() => _items = items);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الطلبات.');
    }
  }

  /// الحالات من الخادم؛ خادم قديم لا يرسلها فنعرض القائمة السابقة
  List<String> _nextFor(OrderItem item) =>
      item.nextStatuses ?? const ['processing', 'shipped', 'delivered'];

  Future<void> _printLabel(OrderItem item) =>
      printParcelLabel(context, _service, item.orderId!, item.orderNumber);

  Future<void> _openDetail(int orderId) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => SellerOrderDetailScreen(orderId: orderId)));
    if (mounted) _load();
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    if (await changeParcelStatus(context, _service, orderId, newStatus)) {
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('طلبات متجري')),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_items == null) {
      return const LoadingIndicator();
    }
    if (_items!.isEmpty) {
      return const AppStateMessage(
          message: 'لا يوجد طلبات على منتجاتك بعد.',
          icon: Icons.receipt_long_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _items!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final item = _items![index];
        final orderNo = item.orderNumber ?? '';
        return Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            key: ValueKey('seller-order-${item.id}'),
            onTap:
                item.orderId == null ? null : () => _openDetail(item.orderId!),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: AppText(
                          item.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      AppText('${item.subtotal.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: AppColors.emerald)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  AppText('طلب رقم: $orderNo • الكمية: ${item.quantity}',
                      style: const TextStyle(
                          color: AppColors.muted, fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: AppText(
                          item.parcelStatus != null
                              ? 'طردك: ${Shipment.statusLabels[item.parcelStatus] ?? item.parcelStatus}'
                              : 'الحالة: ${Order.statusLabels[item.orderStatus] ?? item.orderStatus ?? ''}',
                          style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.emeraldDark),
                        ),
                      ),
                      if (_nextFor(item).isEmpty)
                        AppText(
                          (item.trackingNumber ?? '').isNotEmpty
                              ? 'رقم التتبع: ${item.trackingNumber}'
                              : '',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted),
                        )
                      else
                        PopupMenuButton<String>(
                          // id في هذه القائمة هو رقم المنتج داخل الطلب؛ الحالة تُحدَّث على الطلب نفسه
                          onSelected: (status) =>
                              _updateStatus(item.orderId ?? item.id, status),
                          itemBuilder: (context) => [
                            for (final s in _nextFor(item))
                              PopupMenuItem(
                                value: s,
                                child: AppText(
                                    'تغيير إلى: ${Shipment.statusLabels[s] ?? Order.statusLabels[s] ?? s}'),
                              ),
                          ],
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                AppText('تحديث الحالة',
                                    style: TextStyle(
                                        color: Colors.white, fontSize: 11)),
                                SizedBox(width: 4),
                                Icon(Icons.arrow_drop_down,
                                    color: Colors.white, size: 16),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (canPrintParcelLabel(item))
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        key: ValueKey('parcel-label-${item.id}'),
                        onPressed: () => _printLabel(item),
                        icon: const Icon(Icons.print_outlined, size: 18),
                        label: const AppText('طباعة ملصق الشحنة'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
