import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import 'seller_dashboard_tab.dart';
import 'seller_products_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_wallet_screen.dart';
import '../profile/profile_screen.dart';
import '../chat/chat_screen.dart';

class SellerMainScreen extends StatefulWidget {
  const SellerMainScreen({super.key});

  @override
  State<SellerMainScreen> createState() => _SellerMainScreenState();
}

class _SellerMainScreenState extends State<SellerMainScreen> {
  int _index = 0;

  // خمسة أقسام كحد أقصى للشريط السفلي؛ الرسائل في أعلى لوحة البائع وفي الحساب.
  final _tabs = const [
    SellerDashboardTab(),
    SellerProductsScreen(),
    SellerOrdersScreen(),
    SellerWalletScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _tabs),
      floatingActionButton: _index == 0
          ? FloatingActionButton.extended(
              heroTag: 'seller-assistant',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                    builder: (_) => const ChatScreen(seller: true)),
              ),
              icon: const Icon(Icons.auto_awesome),
              label: AppText(AppLocalizations.of(context)
                  .translate('مساعد المتجر')),
            )
          : null,
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
              icon: const Icon(Icons.inventory_2_outlined),
              selectedIcon: const Icon(Icons.inventory_2),
              label: AppLocalizations.of(context).translate('منتجاتي')),
          NavigationDestination(
              icon: const Icon(Icons.receipt_long_outlined),
              selectedIcon: const Icon(Icons.receipt_long),
              label: AppLocalizations.of(context).translate('الطلبات')),
          NavigationDestination(
              icon: const Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: const Icon(Icons.account_balance_wallet),
              label: AppLocalizations.of(context).translate('محفظتي')),
          NavigationDestination(
              icon: const Icon(Icons.person_outline),
              selectedIcon: const Icon(Icons.person),
              label: AppLocalizations.of(context).translate('الحساب')),
        ],
      ),
    );
  }
}
