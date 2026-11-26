import 'package:flutter/material.dart';
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

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _index = 0;

  // الرئيسية (شغل اليوم)، الطلبات، المنتجات، دعم البائعين، حسابي.
  // محادثات العملاء والمرتجعات تُفتح من بطاقات الرئيسية.
  final _tabs = [
    const EmployeeHomeTab(),
    const AdminOrdersScreen(employeeMode: true),
    const AdminProductsScreen(employeeMode: true),
    AdminSupportScreen(service: AdminOperationsService.employee()),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (index) => setState(() => _index = index),
        indicatorColor: AppColors.goldSoft,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon:
                const Icon(Icons.space_dashboard, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('الرئيسية'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.receipt_long_outlined),
            selectedIcon:
                const Icon(Icons.receipt_long, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('الطلبات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.inventory_2_outlined),
            selectedIcon:
                const Icon(Icons.inventory_2, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('المنتجات'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon:
                const Icon(Icons.support_agent, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('الدعم'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('حسابي'),
          ),
        ],
      ),
    );
  }
}
