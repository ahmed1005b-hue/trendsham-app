import '../../theme/theme_switcher.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/order.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import 'admin_order_detail_screen.dart';

class AdminOrdersScreen extends StatefulWidget {
  final bool employeeMode;
  final AdminService? service;

  /// العرض عند الفتح (من بطاقات الموظف): active | new | late
  final String initialView;

  const AdminOrdersScreen(
      {super.key,
      this.employeeMode = false,
      this.service,
      this.initialView = 'active'});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  late final AdminService _service = widget.service ?? AdminService();
  final _search = TextEditingController();
  late String _view = widget.initialView;
  String? _status;
  List<Order>? _orders;
  String? _error;

  /// نفس عروض الموقع (StaffOrderSearch)؛ الأرشيف للمدير وحده
  Map<String, String> get _views => {
        'active': 'الطلبات الحالية',
        'new': 'جديدة',
        'late': 'متأخرة',
        if (!widget.employeeMode) 'archived': 'المؤرشفة',
      };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final orders = await _service.orders(
          employeeMode: widget.employeeMode,
          query: _search.text.trim(),
          view: _view,
          status: _status);
      if (!mounted) return;
      setState(() => _orders = orders);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الطلبات.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: AppText(widget.employeeMode ? 'طلبات العمل' : 'إدارة الطلبات'),
          actions: const [ThemeToggleButton()]),
      body: Column(
        children: [
          _buildFilters(),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: Column(
        children: [
          TextField(
            key: const ValueKey('orders-search'),
            controller: _search,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => _load(),
            decoration: InputDecoration(
              isDense: true,
              border: const OutlineInputBorder(),
              prefixIcon: const Icon(Icons.search),
              hintText: context.tr('رقم الطلب، اسم الزبون، الهاتف أو البريد'),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in _views.entries)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 6),
                    child: ChoiceChip(
                      key: ValueKey('orders-view-${entry.key}'),
                      label: AppText(entry.value),
                      selected: _view == entry.key,
                      onSelected: (_) {
                        setState(() => _view = entry.key);
                        _load();
                      },
                    ),
                  ),
                const SizedBox(width: 6),
                DropdownButton<String?>(
                  key: const ValueKey('orders-status'),
                  value: _status,
                  hint: const AppText('كل الحالات'),
                  items: [
                    const DropdownMenuItem<String?>(
                        value: null, child: AppText('كل الحالات')),
                    ...Order.statusLabels.entries.map((e) =>
                        DropdownMenuItem<String?>(
                            value: e.key, child: AppText(e.value))),
                  ],
                  onChanged: (value) {
                    setState(() => _status = value);
                    _load();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_orders == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_orders!.isEmpty) {
      final filtered = _search.text.trim().isNotEmpty ||
          _status != null ||
          _view != 'active';
      return AppStateMessage(
          message:
              filtered ? 'لا توجد طلبات تطابق البحث.' : 'لا يوجد طلبات حالياً.',
          icon: Icons.inbox);
    }

    return RefreshIndicator(
      onRefresh: _load,
      color: AppColors.primary,
      child: ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: _orders!.length,
        itemBuilder: (context, index) {
          final order = _orders![index];
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: ListTile(
              title: AppText('طلب #${order.orderNumber}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text(_summary(context, order)),
              trailing: const Icon(Icons.chevron_right),
              isThreeLine: true,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminOrderDetailScreen(
                        orderId: order.id,
                        employeeMode: widget.employeeMode,
                        service: widget.service,
                      ),
                    ));
                _load(); // تحديث القائمة بعد العودة (في حال تغيرت الحالة)
              },
            ),
          );
        },
      ),
    );
  }

  /// الإجمالي والدفع، ثم الحالة وعدد المتاجر (كل نص عبر context.tr).
  String _summary(BuildContext context, Order order) {
    final total = context.tr('الإجمالي');
    final currency = context.tr('ل.س');
    final status = context.tr('الحالة');
    final stores = order.shipments.length > 1
        ? ' • ${context.tr(':n متاجر').replaceAll(':n', '${order.shipments.length}')}'
        : '';
    return '$total: ${order.total.toStringAsFixed(0)} $currency • '
        '${context.tr(order.paymentStatusLabel)}\n'
        '$status: ${context.tr(order.statusLabel)}$stores';
  }
}
