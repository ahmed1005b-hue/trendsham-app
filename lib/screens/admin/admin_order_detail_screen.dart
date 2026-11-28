import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/admin_operations_service.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/order_tracker_timeline.dart';

class AdminOrderDetailScreen extends StatefulWidget {
  final int orderId;
  final bool employeeMode;
  final AdminService? service;

  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
    this.employeeMode = false,
    this.service,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  late final AdminService _service = widget.service ?? AdminService();
  final AdminOperationsService _operations = AdminOperationsService();
  Order? _order;
  String? _error;

  /// نفس قواعد الخادم (StaffOrderStatusChanger): للأمام فقط، و«مدفوع» من زر تأكيد الدفع،
  /// والإلغاء قبل الشحن ولغير المدفوع.
  static const _rank = {
    'pending': 0,
    'paid': 0,
    'processing': 1,
    'shipped': 2,
    'delivered': 3,
  };
  static const _staffStatuses = [
    'processing',
    'shipped',
    'delivered',
    'cancelled'
  ];
  static const _refundMethods = {
    'card': 'إلى بطاقة الزبون',
    'bank_transfer': 'تحويل بنكي',
    'cash': 'نقداً',
  };
  static const _shippedCancelMessage =
      'شُحن هذا الطلب فلا يُلغى. إن رفض الزبون الاستلام سجّل «رفض الاستلام» على الطرد، وإن استلمه فالإرجاع يكون بطلب إرجاع.';
  static const _paidCancelMessage =
      'هذا الطلب مدفوع، فيلغيه المدير مع تسجيل رد المال للزبون.';
  String? _selectedStatus;
  final TextEditingController _trackingController = TextEditingController();
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final order = await _service.getOrder(
        widget.orderId,
        employeeMode: widget.employeeMode,
      );
      setState(() {
        _order = order;
        _selectedStatus = null;
        _trackingController.text = order.shipments.isNotEmpty
            ? (order.shipments.first.trackingNumber ?? '')
            : '';
      });
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الطلب.');
    }
  }

  List<String> _nextStatuses(Order order) => _staffStatuses.where((s) {
        if (s == 'cancelled') {
          return !order.hasShipped && !order.needsRefundBeforeCancel;
        }
        return (_rank[s] ?? 0) > (_rank[order.status] ?? 0);
      }).toList();

  /// يطلب سبب الإلغاء. null عند التراجع.
  Future<String?> _askReason() => showDialog<String>(
      context: context, builder: (_) => const _ReasonDialog());

  Future<void> _updateStatus() async {
    final status = _selectedStatus;
    if (status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: AppText(context.tr('اختر الحالة الجديدة.'))));
      return;
    }
    String? reason;
    if (status == 'cancelled') {
      reason = await _askReason();
      if (!mounted || reason == null) return;
      if (reason.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: AppText(context.tr('اكتب سبب الإلغاء.'))));
        return;
      }
    }
    setState(() => _isUpdating = true);
    try {
      final updatedOrder = await _service.updateOrderStatus(
        widget.orderId,
        status,
        trackingNumber: _trackingController.text.trim(),
        reason: reason,
        employeeMode: widget.employeeMode,
      );
      setState(() {
        _order = updatedOrder;
        _selectedStatus = null;
        _trackingController.text = updatedOrder.shipments.isNotEmpty
            ? (updatedOrder.shipments.first.trackingNumber ?? '')
            : '';
      });
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم تحديث حالة الطلب بنجاح')));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  @override
  void dispose() {
    _trackingController.dispose();
    super.dispose();
  }

  Future<void> _applyOrderAction(
      Future<Order> Function() action, String successMessage) async {
    setState(() => _isUpdating = true);
    try {
      final updated = await action();
      if (!mounted) return;
      setState(() => _order = updated);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(successMessage)));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelWithRefund(Order order) async {
    final result = await showDialog<_RefundAnswer>(
      context: context,
      builder: (_) =>
          _RefundDialog(amount: order.total, methods: _refundMethods),
    );
    if (result == null || !mounted) return;
    await _applyOrderAction(
        () => _service.cancelWithRefund(order.id,
            reason: result.reason, method: result.method, note: result.note),
        'أُلغي الطلب وسُجّل رد المال للزبون.');
  }

  Future<void> _markPaid(Order order) async {
    final ref = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد استلام الدفع'),
        content: TextField(
          controller: ref,
          decoration: InputDecoration(
              labelText: AppLocalizations.of(context)
                  .translate('مرجع العملية (اختياري)')),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('إلغاء')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('تأكيد الدفع')),
        ],
      ),
    );
    if (ok != true) return;
    await _applyOrderAction(
        () => _operations.markPaid(order.id, transactionRef: ref.text.trim()),
        'تم تأكيد الدفع.');
  }

  Future<void> _editShipment(Order order, Shipment shipment) async {
    final companies = await _operations
        .shippingCompanies()
        .catchError((_) => <Map<String, dynamic>>[]);
    if (!mounted) return;
    final tracking = TextEditingController(text: shipment.trackingNumber ?? '');
    String status = shipment.status;
    int? companyId = companies
        .where((c) => c['name'] == shipment.shippingCompany)
        .map((c) => (c['id'] as num).toInt())
        .firstOrNull;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: AppText(shipment.sellerName != null
              ? 'شحنة ${shipment.sellerName}'
              : 'بيانات الشحن'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: Shipment.statusLabels.containsKey(status)
                      ? status
                      : 'pending',
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('حالة الشحنة')),
                  items: Shipment.statusLabels.entries
                      .map((e) => DropdownMenuItem(
                          value: e.key, child: AppText(e.value)))
                      .toList(),
                  onChanged: (v) => setDialog(() => status = v!),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<int?>(
                  initialValue: companyId,
                  isExpanded: true,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('شركة الشحن')),
                  items: [
                    const DropdownMenuItem<int?>(
                        value: null, child: AppText('بدون')),
                    ...companies
                        .where((c) =>
                            c['is_active'] == true ||
                            (c['id'] as num).toInt() == companyId)
                        .map((c) => DropdownMenuItem<int?>(
                            value: (c['id'] as num).toInt(),
                            child: AppText('${c['name']}'))),
                  ],
                  onChanged: (v) => setDialog(() => companyId = v),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: tracking,
                  decoration: InputDecoration(
                      labelText:
                          AppLocalizations.of(context).translate('رقم التتبع')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('حفظ')),
          ],
        ),
      ),
    );
    if (ok != true || shipment.id == null) return;
    await _applyOrderAction(
      () => _operations.updateShipment(
        order.id,
        shipment.id!,
        status: status,
        shippingCompanyId: companyId,
        trackingNumber: tracking.text.trim(),
      ),
      'تم تحديث بيانات الشحن وإشعار العميل.',
    );
  }

  Widget _buildPaymentCard(Order order) {
    final canConfirm =
        !order.isPaid && (order.paymentStatus ?? '').toLowerCase() != 'failed';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.payments_outlined, color: AppColors.emerald),
                const SizedBox(width: 8),
                const AppText('الدفع',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const Spacer(),
                AppText(order.paymentStatusLabel),
              ],
            ),
            if (canConfirm) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: _isUpdating ? null : () => _markPaid(order),
                    icon: const Icon(Icons.check_circle_outline),
                    label: const AppText('تأكيد استلام الدفع'),
                  ),
                  OutlinedButton.icon(
                    onPressed: _isUpdating
                        ? null
                        : () => _applyOrderAction(
                            () => _operations.markFailed(order.id),
                            'تم تعليم الدفع كفاشل.'),
                    icon: const Icon(Icons.cancel_outlined,
                        color: AppColors.danger),
                    label: const AppText('تعليم كفاشل',
                        style: TextStyle(color: AppColors.danger)),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _shipmentDetails(Shipment shipment) {
    final details = [
      if (shipment.shippingCompany != null) shipment.shippingCompany!,
      if ((shipment.trackingNumber ?? '').isNotEmpty)
        'تتبع: ${shipment.trackingNumber}',
    ].join(' • ');
    return details.isEmpty ? 'لم تُحدَّد شركة الشحن بعد' : details;
  }

  Widget _buildShipmentsCard(Order order) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: AppText('الشحنات',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
            for (final shipment in order.shipments)
              ListTile(
                leading: const Icon(Icons.local_shipping_outlined),
                title: AppText(
                    '${shipment.sellerName ?? 'شحنة'} • ${shipment.statusLabel}'),
                subtitle: AppText(_shipmentDetails(shipment)),
                trailing: IconButton(
                  tooltip: context.tr('تعديل الشحنة'),
                  icon: const Icon(Icons.edit_outlined),
                  onPressed:
                      _isUpdating ? null : () => _editShipment(order, shipment),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: AppText(_order?.orderNumber ?? 'تفاصيل الطلب')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_order == null) return const Center(child: CircularProgressIndicator());

    final order = _order!;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // لوحة التحكم بالحالة
        Card(
          color: context.softTint(Colors.blue),
          shape: RoundedRectangleBorder(
            side: BorderSide(color: Colors.blue.shade200, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      widget.employeeMode
                          ? Icons.badge_outlined
                          : Icons.admin_panel_settings,
                      color: Colors.blue,
                    ),
                    const SizedBox(width: 8),
                    const AppText('لوحة تحكم الإدارة',
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.blue)),
                  ],
                ),
                const Divider(),
                AppText(
                    '${context.tr('الحالة الحالية')}: ${context.tr(order.statusLabel)}',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                if (order.status == 'cancelled')
                  const AppText('الطلب ملغى.')
                else ...[
                  const AppText('تحديث حالة الطلب:'),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    key: ValueKey('order-status-${order.status}'),
                    initialValue: _selectedStatus,
                    hint: const AppText('اختر الحالة الجديدة'),
                    decoration: const InputDecoration(
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                    items: _nextStatuses(order)
                        .map((s) => DropdownMenuItem(
                            value: s,
                            child: AppText(Order.statusLabels[s] ?? s)))
                        .toList(),
                    onChanged: (val) => setState(() => _selectedStatus = val),
                  ),
                  const SizedBox(height: 6),
                  const AppText('الحالة تتقدم للأمام فقط.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted)),
                  if (order.hasShipped)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: AppText(_shippedCancelMessage,
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                    )
                  else if (order.needsRefundBeforeCancel && widget.employeeMode)
                    const Padding(
                      padding: EdgeInsets.only(top: 6),
                      child: AppText(_paidCancelMessage,
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                    ),
                  const SizedBox(height: 12),
                ],
                if (!widget.employeeMode) ...[
                  const AppText('رقم بوليصة الشحن (اختياري):'),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _trackingController,
                    decoration: InputDecoration(
                      border: const OutlineInputBorder(),
                      hintText: AppLocalizations.of(context)
                          .translate('أدخل رقم التتبع هنا ليراه العميل...'),
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 12),
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                if (order.status != 'cancelled')
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      key: const ValueKey('order-status-save'),
                      onPressed: _isUpdating ? null : _updateStatus,
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white),
                      child: _isUpdating
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const AppText('حفظ التحديثات',
                              style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                if (!widget.employeeMode &&
                    order.status != 'cancelled' &&
                    order.needsRefundBeforeCancel &&
                    !order.hasShipped) ...[
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      key: const ValueKey('order-cancel-refund'),
                      onPressed:
                          _isUpdating ? null : () => _cancelWithRefund(order),
                      icon: const Icon(Icons.currency_exchange,
                          color: AppColors.danger),
                      label: const AppText(
                          'إلغاء الطلب المدفوع وتسجيل رد المال',
                          style: TextStyle(color: AppColors.danger)),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        if (!widget.employeeMode) ...[
          const SizedBox(height: 16),
          _buildPaymentCard(order),
          if (order.shipments.isNotEmpty) ...[
            const SizedBox(height: 16),
            _buildShipmentsCard(order),
          ],
        ],
        const SizedBox(height: 16),

        // التتبع (نفس خط العميل لمعاينة الشكل)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OrderTrackerTimeline(
              status: order.status,
              trackingNumber: order.shipments.isNotEmpty
                  ? order.shipments.first.trackingNumber
                  : null,
              shippingCompany: order.shipments.isNotEmpty
                  ? order.shipments.first.shippingCompany
                  : null,
            ),
          ),
        ),
        const SizedBox(height: 16),

        // المنتجات
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('المنتجات المطلوبة',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...order.items.map((item) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                              child: AppText(
                                  '${item.displayName} × ${item.quantity}')),
                          AppText('${item.subtotal.toStringAsFixed(0)} ل.س'),
                        ],
                      ),
                    )),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const AppText('الإجمالي',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    AppText('${order.total.toStringAsFixed(0)} ل.س',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // بيانات العميل
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText('بيانات العميل وعنوان التوصيل',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                AppText('${order.shippingName} - ${order.shippingPhone}',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
                AppText(order.shippingAddress,
                    style: const TextStyle(color: AppColors.muted)),
              ],
            ),
          ),
        ),
        if (widget.employeeMode && order.archivedAt == null) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const AppText('أرشفة الطلب'),
                  content: const AppText(
                      'سيُخفى الطلب من قائمة العمل مع الاحتفاظ بسجله.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(dialogContext, false),
                      child: const AppText('إلغاء'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(dialogContext, true),
                      child: const AppText('أرشفة'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              try {
                await _service.archiveEmployeeOrder(order.id);
                if (mounted) Navigator.pop(context);
              } on ApiException catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: AppText(e.message)));
                }
              }
            },
            icon: const Icon(Icons.archive_outlined),
            label: const AppText('أرشفة مع الاحتفاظ بالسجل'),
          ),
        ],
      ],
    );
  }
}

class _RefundAnswer {
  const _RefundAnswer(this.method, this.reason, this.note);
  final String method;
  final String reason;
  final String note;
}

/// إلغاء طلب مدفوع: كيف رُدّ المال، وسبب الإلغاء (يصل للزبون والبائع).
class _RefundDialog extends StatefulWidget {
  const _RefundDialog({required this.amount, required this.methods});

  final double amount;
  final Map<String, String> methods;

  @override
  State<_RefundDialog> createState() => _RefundDialogState();
}

class _RefundDialogState extends State<_RefundDialog> {
  String? _method;
  final _reason = TextEditingController();
  final _note = TextEditingController();
  String? _problem;

  @override
  void dispose() {
    _reason.dispose();
    _note.dispose();
    super.dispose();
  }

  void _submit() {
    final problem = _method == null
        ? 'اختر كيف رُدّ المال للزبون.'
        : _reason.text.trim().isEmpty
            ? 'اكتب سبب الإلغاء.'
            : null;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context,
        _RefundAnswer(_method!, _reason.text.trim(), _note.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    final amount = '${widget.amount.toStringAsFixed(0)} ل.س';
    return AlertDialog(
      title: const AppText('إلغاء الطلب المدفوع وتسجيل رد المال'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context
                .tr('المبلغ المدفوع الذي يجب رده: :amount. رصيد الهدايا (إن وُجد) يعود للزبون تلقائياً.')
                .replaceAll(':amount', amount)),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              key: const ValueKey('refund-method'),
              initialValue: _method,
              hint: const AppText('كيف رُدّ المال؟'),
              items: widget.methods.entries
                  .map((e) =>
                      DropdownMenuItem(value: e.key, child: AppText(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _method = v),
            ),
            TextField(
              key: const ValueKey('refund-note'),
              controller: _note,
              maxLength: 255,
              decoration: InputDecoration(
                  labelText: context.tr('رقم العملية أو ملاحظة (اختياري)')),
            ),
            TextField(
              key: const ValueKey('refund-reason'),
              controller: _reason,
              maxLength: 500,
              maxLines: 2,
              decoration: InputDecoration(
                  labelText: context.tr('سبب الإلغاء (يصل للزبون والبائع)')),
            ),
            if (_problem != null)
              AppText(_problem!,
                  style: const TextStyle(color: AppColors.danger)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('تراجع')),
        FilledButton(
            key: const ValueKey('refund-submit'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: _submit,
            child: const AppText('ألغِ الطلب وسجّل رد المال')),
      ],
    );
  }
}

/// سبب الإلغاء (يصل للزبون والبائع). الحقل يملكه الحوار فيبقى حياً حتى يُغلق.
class _ReasonDialog extends StatefulWidget {
  const _ReasonDialog();

  @override
  State<_ReasonDialog> createState() => _ReasonDialogState();
}

class _ReasonDialogState extends State<_ReasonDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const AppText('سبب الإلغاء'),
      content: TextField(
        key: const ValueKey('order-cancel-reason'),
        controller: _controller,
        autofocus: true,
        maxLength: 500,
        maxLines: 3,
        decoration: InputDecoration(
            hintText: context.tr('سبب الإلغاء (يصل للزبون والبائع)')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: const AppText('تراجع')),
        FilledButton(
            key: const ValueKey('order-cancel-confirm'),
            onPressed: () => Navigator.pop(context, _controller.text.trim()),
            child: const AppText('ألغِ الطلب')),
      ],
    );
  }
}
