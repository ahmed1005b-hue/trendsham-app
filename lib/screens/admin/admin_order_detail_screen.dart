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

  const AdminOrderDetailScreen({
    super.key,
    required this.orderId,
    this.employeeMode = false,
  });

  @override
  State<AdminOrderDetailScreen> createState() => _AdminOrderDetailScreenState();
}

class _AdminOrderDetailScreenState extends State<AdminOrderDetailScreen> {
  final AdminService _service = AdminService();
  final AdminOperationsService _operations = AdminOperationsService();
  Order? _order;
  String? _error;

  static const _employeeStatuses = {
    'processing',
    'shipped',
    'delivered',
    'cancelled'
  };
  String _selectedStatus = 'pending';
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
        _selectedStatus = order.status;
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

  Future<void> _updateStatus() async {
    setState(() => _isUpdating = true);
    try {
      final updatedOrder = await _service.updateOrderStatus(
        widget.orderId,
        _selectedStatus,
        trackingNumber: _trackingController.text.trim(),
        employeeMode: widget.employeeMode,
      );
      setState(() {
        _order = updatedOrder;
        _selectedStatus = updatedOrder.status;
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
                const AppText('تحديث حالة الطلب:'),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: _selectedStatus,
                  decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  // الموظف: لا «مدفوع» ولا رجوع للمراجعة (نفس قواعد الخادم)
                  items: Order.statusLabels.entries
                      .where((e) =>
                          !widget.employeeMode ||
                          e.key == _selectedStatus ||
                          _employeeStatuses.contains(e.key))
                      .map((e) {
                    return DropdownMenuItem(
                        value: e.key, child: AppText(e.value));
                  }).toList(),
                  onChanged: (val) => setState(() => _selectedStatus = val!),
                ),
                const SizedBox(height: 12),
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
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
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
