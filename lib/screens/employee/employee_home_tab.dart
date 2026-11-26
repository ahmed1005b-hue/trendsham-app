import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../theme/theme_switcher.dart';
import '../../widgets/app_state_message.dart';
import '../admin/admin_assistant_screen.dart';
import '../admin/admin_orders_screen.dart';
import '../admin/admin_products_screen.dart';
import '../admin/admin_returns_screen.dart';
import '../admin/admin_support_screen.dart';
import '../../services/admin_operations_service.dart';
import '../../services/admin_review_service.dart';

/// الصفحة الرئيسية للموظف: شغل اليوم بالأرقام، وكل بطاقة تفتح قائمتها (مثل الموقع).
class EmployeeHomeTab extends StatefulWidget {
  const EmployeeHomeTab({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminService? service;

  @override
  State<EmployeeHomeTab> createState() => _EmployeeHomeTabState();
}

class _EmployeeHomeTabState extends State<EmployeeHomeTab> {
  late final AdminService _service = widget.service ?? AdminService();
  Map<String, int>? _counts;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final counts = await _service.employeeDashboard();
      if (mounted) setState(() => _counts = counts);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل شغل اليوم.');
    }
  }

  Future<void> _open(Widget screen) async {
    await Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('لوحة الموظف'),
        actions: const [ThemeToggleButton()],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.emerald,
        child: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final counts = _counts;
    if (counts == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final tiles = <_WorkTile>[
      _WorkTile(
          'new_orders',
          Icons.shopping_bag_outlined,
          'طلبات جديدة',
          'طلبات وصلت للبائعين ولم تُجهَّز بعد.',
          () => _open(const AdminOrdersScreen(employeeMode: true))),
      _WorkTile(
          'late_orders',
          Icons.hourglass_bottom,
          'طلبات متأخرة',
          'طلبات لم تُشحن منذ أيام.',
          () => _open(const AdminOrdersScreen(employeeMode: true)),
          urgent: true),
      _WorkTile(
          'pending_products',
          Icons.fact_check_outlined,
          'منتجات تنتظر المراجعة',
          'اقبلها أو ارفضها مع ذكر السبب.',
          () => _open(const AdminProductsScreen(employeeMode: true))),
      _WorkTile(
          'customer_chats',
          Icons.chat_outlined,
          'محادثات العملاء',
          'عملاء طلبوا التحدث مع موظف.',
          () => _open(const AdminAssistantScreen(employeeMode: true)),
          urgent: true),
      _WorkTile(
          'seller_support',
          Icons.support_agent,
          'دعم البائعين',
          'رسائل بائعين لم تُقرأ بعد.',
          () => _open(
              AdminSupportScreen(service: AdminOperationsService.employee()))),
      _WorkTile(
          'returns',
          Icons.assignment_return_outlined,
          'المرتجعات',
          'نزاعات إرجاع تحتاج قراراً. إرجاع المال يسجّله المدير.',
          () => _open(
              AdminReturnsScreen(service: AdminReviewService.employee()))),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AppText('شغل اليوم: ما ينتظر تصرّفك الآن.',
            style: TextStyle(color: AppColors.muted)),
        const SizedBox(height: 12),
        for (final tile in tiles) _buildTile(tile, counts[tile.key] ?? 0),
      ],
    );
  }

  Widget _buildTile(_WorkTile tile, int count) {
    final active = count > 0;
    final badgeColor = !active
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : (tile.urgent ? Colors.red : AppColors.emerald);
    return Card(
      key: ValueKey('employee-tile-${tile.key}'),
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        onTap: tile.onTap,
        leading: Icon(tile.icon, color: AppColors.emerald),
        title: AppText(tile.label,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: AppText(tile.hint),
        trailing: Container(
          constraints: const BoxConstraints(minWidth: 34),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
              color: badgeColor, borderRadius: BorderRadius.circular(20)),
          child: Text(
            '$count',
            key: ValueKey('employee-count-${tile.key}'),
            textAlign: TextAlign.center,
            style: TextStyle(
                fontWeight: FontWeight.bold,
                color: active ? Colors.white : null),
          ),
        ),
      ),
    );
  }
}

class _WorkTile {
  const _WorkTile(this.key, this.icon, this.label, this.hint, this.onTap,
      {this.urgent = false});

  final String key;
  final IconData icon;
  final String label;
  final String hint;
  final VoidCallback onTap;
  final bool urgent;
}
