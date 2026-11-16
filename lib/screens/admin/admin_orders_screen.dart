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

  const AdminOrdersScreen({super.key, this.employeeMode = false});

  @override
  State<AdminOrdersScreen> createState() => _AdminOrdersScreenState();
}

class _AdminOrdersScreenState extends State<AdminOrdersScreen> {
  final AdminService _service = AdminService();
  List<Order>? _orders;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final orders = await _service.orders(employeeMode: widget.employeeMode);
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
      body: _buildBody(),
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
      return const AppStateMessage(
          message: 'لا يوجد طلبات حالياً.', icon: Icons.inbox);
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
              subtitle: AppText(
                  'الإجمالي: ${order.total.toStringAsFixed(0)} ل.س\nالحالة: ${order.statusLabel}'),
              trailing: const Icon(Icons.chevron_right),
              isThreeLine: true,
              onTap: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AdminOrderDetailScreen(
                        orderId: order.id,
                        employeeMode: widget.employeeMode,
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
}
