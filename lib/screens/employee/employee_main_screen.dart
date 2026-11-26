import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../admin/admin_orders_screen.dart';
import '../admin/admin_products_screen.dart';
import '../admin/admin_support_screen.dart';
import '../../services/admin_operations_service.dart';
import 'employee_home_tab.dart';
import '../profile/profile_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeTab {
  const _EmployeeTab(
      this.section, this.icon, this.selectedIcon, this.label, this.build);

  /// القسم الذي يحتاجه التبويب (null = متاح دائماً).
  final String? section;
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final Widget Function() build;
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _index = 0;

  // الرئيسية (شغل اليوم)، ثم أقسام الموظف التي سمح بها المدير، ثم حسابي.
  // محادثات العملاء والمرتجعات تُفتح من بطاقات الرئيسية.
  static final _allTabs = [
    _EmployeeTab(null, Icons.space_dashboard_outlined, Icons.space_dashboard,
        'الرئيسية', () => const EmployeeHomeTab()),
    _EmployeeTab('orders', Icons.receipt_long_outlined, Icons.receipt_long,
        'الطلبات', () => const AdminOrdersScreen(employeeMode: true)),
    _EmployeeTab('products', Icons.inventory_2_outlined, Icons.inventory_2,
        'المنتجات', () => const AdminProductsScreen(employeeMode: true)),
    _EmployeeTab(
        'support',
        Icons.support_agent_outlined,
        Icons.support_agent,
        'الدعم',
        () => AdminSupportScreen(service: AdminOperationsService.employee())),
    _EmployeeTab(null, Icons.person_outline, Icons.person, 'حسابي',
        () => const ProfileScreen()),
  ];

  /// الشاشات تُبنى مرة واحدة فتبقى حالتها عند التنقل بين التبويبات.
  final Map<String, Widget> _built = {};

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final tabs = _allTabs
        .where(
            (t) => t.section == null || (user?.canWorkOn(t.section!) ?? false))
        .toList();
    final index = _index.clamp(0, tabs.length - 1);
    final l = AppLocalizations.of(context);

    return Scaffold(
      body: IndexedStack(
        index: index,
        children: [
          for (final tab in tabs) _built.putIfAbsent(tab.label, tab.build),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (i) => setState(() => _index = i),
        indicatorColor: AppColors.goldSoft,
        destinations: [
          for (final tab in tabs)
            NavigationDestination(
              key: ValueKey('employee-nav-${tab.section ?? tab.label}'),
              icon: Icon(tab.icon),
              selectedIcon: Icon(tab.selectedIcon, color: AppColors.primary),
              label: l.translate(tab.label),
            ),
        ],
      ),
    );
  }
}
