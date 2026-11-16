import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import 'admin_dashboard_tab.dart';
import 'admin_sellers_screen.dart';
import 'admin_products_screen.dart';
import 'admin_withdrawals_screen.dart';
import '../profile/profile_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;

  final _tabs = const [
    AdminDashboardTab(),
    AdminSellersScreen(),
    AdminProductsScreen(),
    AdminWithdrawalsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        backgroundColor: Theme.of(context).colorScheme.surface,
        indicatorColor: AppColors.emerald.withValues(alpha: 0.12),
        destinations: [
          NavigationDestination(
              icon: const Icon(Icons.dashboard_outlined),
              selectedIcon: const Icon(Icons.dashboard),
              label: AppLocalizations.of(context).translate('الرئيسية')),
          NavigationDestination(
              icon: const Icon(Icons.storefront_outlined),
              selectedIcon: const Icon(Icons.storefront),
              label: AppLocalizations.of(context).translate('البائعون')),
          NavigationDestination(
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: AppLocalizations.of(context).translate('المنتجات')),
          NavigationDestination(
              icon: const Icon(Icons.payments_outlined),
              selectedIcon: const Icon(Icons.payments),
              label: AppLocalizations.of(context).translate('الطلبات')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: AppLocalizations.of(context).translate('الحساب')),
        ],
      ),
    );
  }
}
