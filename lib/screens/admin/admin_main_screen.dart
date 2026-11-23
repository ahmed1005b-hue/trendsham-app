import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import 'admin_dashboard_tab.dart';
import 'admin_sellers_screen.dart';
import 'admin_products_screen.dart';
import 'admin_withdrawals_screen.dart';
import '../profile/profile_screen.dart';
import '../../services/admin_tools_service.dart';
import '../../widgets/app_state_message.dart';
import 'admin_two_factor_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});

  /// هل يحتاج المدير إعداد التحقق بخطوتين قبل اللوحة؟ (قابل للاستبدال في الاختبارات)
  static Future<bool> Function() needsTwoFactorSetup =
      () async => (await AdminToolsService().twoFactor()).needsSetup;

  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;

  /// null = نتحقق الآن. اللوحة مقفلة حتى يُعدّ التحقق بخطوتين (مثل الموقع)
  bool? _needsSetup;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  Future<void> _checkSetup() async {
    bool needs;
    try {
      needs = await AdminMainScreen.needsTwoFactorSetup();
    } catch (_) {
      // تعذّر الفحص: نعرض اللوحة، وكل شاشة تعرض رسالة الخادم إن رفض
      needs = false;
    }
    if (mounted) setState(() => _needsSetup = needs);
  }

  final _tabs = const [
    AdminDashboardTab(),
    AdminSellersScreen(),
    AdminProductsScreen(),
    AdminWithdrawalsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    if (_needsSetup == null) {
      return const Scaffold(body: LoadingIndicator());
    }
    if (_needsSetup!) {
      return AdminTwoFactorScreen(
          onEnabled: () => setState(() => _needsSetup = false));
    }
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
