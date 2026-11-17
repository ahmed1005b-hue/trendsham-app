import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/store_service.dart';
import '../../services/checkout_service.dart';
import '../../services/api_exception.dart';
import '../../services/payment_api.dart';
import '../../services/return_service.dart';
import '../../models/return_request.dart';
import '../returns/create_return_screen.dart';
import '../../utils/file_share.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/order_tracker_timeline.dart';
import '../messages/buyer_seller_messages_screen.dart';
import '../../widgets/saved_card_picker.dart';
import '../../l10n/app_localizations.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;

  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  final OrderService _orderService = OrderService();
  final PaymentApi _paymentApi = PaymentApi();
  final ReturnService _returnService = ReturnService();
  List<ReturnableLine> _returnable = const [];
  Order? _order;
  String? _error;
  bool _isCancelling = false;
  bool _isPaying = false;
  bool _loadingInvoice = false;
  String? _payStatus;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _openInvoice() async {
    final order = _order;
    if (order == null || _loadingInvoice) return;
    setState(() => _loadingInvoice = true);
    try {
      final bytes = await _orderService.invoice(order.id);
      await openPdfBytes(bytes, 'invoice-${order.orderNumber}.pdf');
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _loadingInvoice = false);
    }
  }

  Future<void> _startPayment() async {
    if (_isPaying || _order == null) return;
    final choice = await chooseCardForPayment(context,
        amountLabel: '${_order!.total.toStringAsFixed(0)} ل.س',
        api: _paymentApi);
    if (choice == null || !mounted) return;
    setState(() {
      _isPaying = true;
      _payStatus = 'جارٍ بدء عملية الدفع...';
    });
    try {
      final start =
          await _paymentApi.startPayment(_order!.id, cardId: choice.cardId);
      if (!mounted) return;
      if (start.type == 'paid' || start.type == 'failed') {
        await _payDialog(
            start.paid ? 'تم الدفع بنجاح' : 'لم تكتمل عملية الدفع',
            start.paid
                ? 'تم خصم المبلغ من بطاقتك وتأكيد طلبك.'
                : (start.message ?? 'رفض البنك العملية. جرّب بطاقة أخرى.'),
            start.paid);
        await _load();
        return;
      }
      if (start.type == 'manual') {
        await _payDialog(
            'تم تأكيد الطلب',
            start.message ?? 'سيتم الدفع عند الاستلام، وسنؤكد طلبك قريباً.',
            true);
        await _load();
        return;
      }
      if (start.type == 'redirect' && (start.url ?? '').isNotEmpty) {
        final opened = await _paymentApi.openCheckout(start.url!);
        if (!mounted) return;
        if (!opened) {
          await _payDialog(
              'تعذّر فتح صفحة الدفع', 'يمكنك المحاولة مرة أخرى.', false);
          return;
        }
        setState(() => _payStatus = 'بانتظار تأكيد الدفع من البنك...');
        final st = await _paymentApi.pollStatus(_order!.id,
            attempts: 20, interval: const Duration(seconds: 3));
        if (!mounted) return;
        if (st.paid) {
          await _payDialog(
              'تم الدفع بنجاح', 'تم استلام الدفع وتأكيد طلبك.', true);
        } else if (st.failed) {
          await _payDialog(
              'لم تكتمل عملية الدفع', 'يمكنك إعادة المحاولة.', false);
        } else {
          await _payDialog('قيد التحقق',
              'قد يستغرق التأكيد لحظات. حدّث الحالة لاحقاً.', false);
        }
        await _load();
        return;
      }
      await _payDialog('تم', start.message ?? 'تم إنشاء عملية الدفع.', true);
      await _load();
    } on ApiException catch (e) {
      if (mounted) await _payDialog('تنبيه الدفع', e.message, false);
    } finally {
      if (mounted) {
        setState(() {
          _isPaying = false;
          _payStatus = null;
        });
      }
    }
  }

  Future<void> _payDialog(String title, String msg, bool ok) =>
      showDialog<void>(
        context: context,
        builder: (ctx) => Directionality(
            textDirection: TextDirection.rtl,
            child: AlertDialog(
              title: AppText(title,
                  style: TextStyle(
                      color: ok ? AppColors.brandGreen : AppColors.danger)),
              content: AppText(msg),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const AppText('حسناً'))
              ],
            )),
      );

  Widget _paymentBadge(String? status) {
    final st = (status ?? 'none').toLowerCase();
    Color bg;
    Color fg;
    String label;
    IconData icon;
    if (st == 'paid') {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = Colors.green.shade700;
      label = 'مدفوع';
      icon = Icons.verified_rounded;
    } else if (st == 'failed' || st == 'cancelled') {
      bg = AppColors.danger.withValues(alpha: 0.12);
      fg = AppColors.danger;
      label = st == 'cancelled' ? 'ملغي الدفع' : 'فشل الدفع';
      icon = Icons.error_outline;
    } else {
      bg = const Color(0xFFF2994A).withValues(alpha: 0.12);
      fg = const Color(0xFFB96A1A);
      label = 'غير مدفوع';
      icon = Icons.payments_outlined;
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: fg, size: 14),
          const SizedBox(width: 4),
          AppText(label,
              style: TextStyle(
                  color: fg, fontSize: 12, fontWeight: FontWeight.bold))
        ]));
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final order = await _orderService.show(widget.orderId);
      setState(() => _order = order);
      _loadReturnable();
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الطلب.');
    }
  }

  /// أسطر قابلة للإرجاع؛ فشل الطلب لا يمنع عرض الطلب نفسه.
  Future<void> _loadReturnable() async {
    try {
      final lines = await _returnService.returnable(widget.orderId);
      if (!mounted) return;
      setState(() =>
          _returnable = lines.where((l) => l.returnableQuantity > 0).toList());
    } catch (_) {
      if (mounted) setState(() => _returnable = const []);
    }
  }

  Future<void> _openReturnForm() async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => CreateReturnScreen(
            orderId: widget.orderId, lines: _returnable)));
    if (mounted) _loadReturnable();
  }

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الإلغاء'),
        content: const AppText('هل أنت متأكد إنك بدك تلغي هذا الطلب؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('نعم، ألغِ')),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isCancelling = true);
    try {
      final order = await _orderService.cancel(widget.orderId);
      setState(() => _order = order);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم إلغاء الطلب.')),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _showReviewDialog(int orderItemId, String productName) async {
    int rating = 5;
    final commentController = TextEditingController();
    bool isSubmitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: AppText('قيّم $productName'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(5, (i) {
                  return IconButton(
                    tooltip: context.tr('تقييم ${i + 1} من 5'),
                    icon: Icon(
                      i < rating ? Icons.star : Icons.star_border,
                      color: AppColors.gold,
                    ),
                    onPressed: isSubmitting
                        ? null
                        : () => setDialogState(() => rating = i + 1),
                  );
                }),
              ),
              TextField(
                controller: commentController,
                enabled: !isSubmitting,
                decoration: InputDecoration(hintText: context.tr('تعليق (اختياري)')),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
                child: const AppText('إلغاء')),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      setDialogState(() => isSubmitting = true);
                      try {
                        await _orderService.submitReview(orderItemId,
                            rating: rating, comment: commentController.text);
                        if (!ctx.mounted) return;
                        Navigator.pop(ctx);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: AppText('تم إرسال تقييم المنتج بنجاح.'),
                            backgroundColor: AppColors.primary,
                          ),
                        );
                      } on ApiException catch (e) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            SnackBar(content: AppText(e.message)),
                          );
                        }
                      } catch (_) {
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(
                            const SnackBar(
                              content: AppText('تعذّر إرسال تقييم المنتج.'),
                            ),
                          );
                        }
                      } finally {
                        if (ctx.mounted) {
                          setDialogState(() => isSubmitting = false);
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const AppText('إرسال'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: AppText(_order?.orderNumber ?? 'تفاصيل الطلب'),
        actions: [
          if (_order != null)
            IconButton(
              tooltip: context.tr('الفاتورة'),
              onPressed: _loadingInvoice ? null : _openInvoice,
              icon: _loadingInvoice
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.receipt_long_outlined),
            ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_order == null) {
      return const LoadingIndicator();
    }

    final order = _order!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (order.canBeCancelled)
            Card(
              color: Colors.amber.shade50,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    const Expanded(
                        child: AppText('طلبك لسا قيد المراجعة، بتقدر تلغيه.',
                            style: TextStyle(fontSize: 13))),
                    TextButton(
                      onPressed: _isCancelling ? null : _cancelOrder,
                      child: _isCancelling
                          ? const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const AppText('إلغاء الطلب',
                              style: TextStyle(color: AppColors.danger)),
                    ),
                  ],
                ),
              ),
            ),
          if (_returnable.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.assignment_return_outlined),
                title: const AppText('طلب إرجاع'),
                subtitle: const AppText('بعض منتجات هذا الطلب قابلة للإرجاع.',
                    style: TextStyle(fontSize: 12)),
                trailing: const Icon(Icons.chevron_right),
                onTap: _openReturnForm,
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('المنتجات',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...order.items.map((item) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      AppText(
                                          '${item.displayName} × ${item.quantity}'),
                                      Row(children: [
                                        AppText(
                                            '${item.unitPrice.toStringAsFixed(0)} ل.س',
                                            style: const TextStyle(
                                                fontSize: 12,
                                                color: AppColors.muted)),
                                        if (item.hasDealPrice &&
                                            item.originalUnitPrice != null &&
                                            item.originalUnitPrice! >
                                                item.unitPrice) ...[
                                          const SizedBox(width: 6),
                                          AppText(
                                              '${item.originalUnitPrice!.toStringAsFixed(0)} ل.س',
                                              style: const TextStyle(
                                                  fontSize: 11,
                                                  color: AppColors.muted,
                                                  decoration: TextDecoration
                                                      .lineThrough)),
                                          if (item.dealDiscountPercentage !=
                                              null)
                                            AppText(
                                                ' -${item.dealDiscountPercentage}%',
                                                style: const TextStyle(
                                                    fontSize: 11,
                                                    color:
                                                        AppColors.primaryDark,
                                                    fontWeight:
                                                        FontWeight.w700)),
                                        ],
                                      ]),
                                    ],
                                  ),
                                ),
                                AppText('${item.subtotal.toStringAsFixed(0)} ل.س'),
                              ],
                            ),
                            if (item.canBeReviewed)
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton.icon(
                                  onPressed: () => _showReviewDialog(
                                      item.id, item.productName),
                                  icon: const Icon(Icons.star_border, size: 16),
                                  label: const AppText('قيّم المنتج'),
                                ),
                              )
                            else if (item.hasReview == true)
                              const AppText('تم تقييمك لهذا المنتج ✓',
                                  style: TextStyle(
                                      color: AppColors.emerald, fontSize: 12)),
                          ],
                        ),
                      )),
                  const Divider(),
                  _summaryRow('المجموع الفرعي', order.subtotal),
                  if (order.discountAmount > 0)
                    _summaryRow('الخصم', -order.discountAmount,
                        valueColor: AppColors.primaryDark),
                  _summaryRow('الشحن', order.shippingFee),
                  if (order.shippingDebtCharged > 0)
                    _summaryRow(
                        'أجرة شحن طلب رفضت استلامه', order.shippingDebtCharged,
                        valueColor: AppColors.danger),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const AppText('الإجمالي',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      AppText('${order.total.toStringAsFixed(0)} ل.س',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const AppText('الأسعار المسجلة في الطلب نهائية وقت الشراء.',
                      style: TextStyle(color: AppColors.muted, fontSize: 11)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (order.shipments.isNotEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const AppText('الشحن',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...order.shipments.map((shipment) => Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (shipment.sellerName != null)
                                AppText(shipment.sellerName!,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w600)),
                              AppText('الحالة: ${shipment.statusLabel}'),
                              if (shipment.shippingCompany != null)
                                AppText('شركة الشحن: ${shipment.shippingCompany}'),
                              if (shipment.trackingNumber != null)
                                AppText('رقم التتبع: ${shipment.trackingNumber}'),
                              if (shipment.sellerProfileId != null)
                                TextButton.icon(
                                  onPressed: () =>
                                      _messageSeller(shipment.sellerProfileId!),
                                  icon: const Icon(Icons.chat_bubble_outline,
                                      size: 16),
                                  label: const AppText('راسل البائع'),
                                ),
                            ],
                          ),
                        )),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const AppText('حالة الدفع',
                            style: TextStyle(fontWeight: FontWeight.bold)),
                        _paymentBadge(order.paymentStatus),
                      ]),
                  if (_isPaying) ...[
                    const SizedBox(height: 10),
                    Row(children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 8),
                      Expanded(child: AppText(_payStatus ?? 'جارٍ المعالجة...'))
                    ]),
                  ],
                  if (!_isPaying &&
                      order.awaitsOnlinePayment &&
                      (order.paymentStatus == null ||
                          [
                            'none',
                            'pending',
                            'failed',
                            'cancelled',
                            'unpaid',
                            ''
                          ].contains(
                              (order.paymentStatus ?? '').toLowerCase())) &&
                      !(order.isPaid)) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                            onPressed: _startPayment,
                            style: FilledButton.styleFrom(
                                backgroundColor: AppColors.brandGreen),
                            icon: const Icon(Icons.payment_rounded),
                            label: AppText((order.paymentStatus == 'failed' ||
                                    order.paymentStatus == 'cancelled')
                                ? 'إعادة محاولة الدفع'
                                : 'ادفع / أكّد الدفع'))),
                    const SizedBox(height: 4),
                    const AppText(
                        'الدفع الإلكتروني يتم عبر صفحة بنك آمنة؛ لا نجمع بيانات البطاقة داخل التطبيق.',
                        style: TextStyle(color: AppColors.muted, fontSize: 11)),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(
                      order.deliveryMethod == 'center'
                          ? 'الاستلام من مركز شحن'
                          : 'عنوان التوصيل',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  AppText('${order.shippingName} - ${order.shippingPhone}'),
                  AppText(order.shippingAddress,
                      style: const TextStyle(color: AppColors.muted)),
                  if (order.refused)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: AppText('رفضت استلام هذا الطلب.',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppText('حالة الطلب',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Chip(label: AppText(order.statusLabel)),
                  const SizedBox(height: 12),
                  OrderTrackerTimeline(
                    status: order.status,
                    trackingNumber: order.shipments.isNotEmpty
                        ? order.shipments.first.trackingNumber
                        : null,
                    shippingCompany: order.shipments.isNotEmpty
                        ? order.shipments.first.shippingCompany
                        : null,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _messageSeller(int storeId) async {
    try {
      final service = StoreService();
      final id = await service.startConversation(storeId);
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BuyerSellerMessagesScreen(conversationId: id),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تعذّر فتح المحادثة.')),
        );
      }
    }
  }

  Widget _summaryRow(String label, double value, {Color? valueColor}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AppText(label),
            AppText(
                '${value < 0 ? '- ' : ''}${value.abs().toStringAsFixed(0)} ل.س',
                style: TextStyle(color: valueColor)),
          ],
        ),
      );
}
