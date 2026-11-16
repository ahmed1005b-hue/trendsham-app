import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../admin/admin_orders_screen.dart';
import '../admin/admin_products_screen.dart';
import '../profile/profile_screen.dart';

class EmployeeMainScreen extends StatefulWidget {
  const EmployeeMainScreen({super.key});

  @override
  State<EmployeeMainScreen> createState() => _EmployeeMainScreenState();
}

class _EmployeeMainScreenState extends State<EmployeeMainScreen> {
  int _index = 0;

  static const _tabs = [
    AdminOrdersScreen(employeeMode: true),
    AdminProductsScreen(employeeMode: true),
    ProfileScreen(),
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
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person, color: AppColors.primary),
            label: AppLocalizations.of(context).translate('حسابي'),
          ),
        ],
      ),
    );
  }
}
