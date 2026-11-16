import 'dart:ui';

import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../utils/auth_prompt.dart';
import 'home_tab.dart';
import '../cart/cart_screen.dart';
import '../favorites/favorites_screen.dart';
import '../orders/orders_screen.dart';
import '../profile/profile_screen.dart';

enum _MainDestination {
  home,
  orders,
  favorites,
  cart,
  account;

  bool get requiresAuthentication => this == orders || this == cart;
}

class MainScreen extends StatefulWidget {
  const MainScreen({
    super.key,
    @visibleForTesting this.tabOverrides,
  });

  @visibleForTesting
  final List<Widget>? tabOverrides;

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class CartNavTarget {
  static final GlobalKey iconKey = GlobalKey(debugLabel: 'cart-nav-icon');
}

class _MainScreenState extends State<MainScreen> {
  _MainDestination _destination = _MainDestination.home;
  late final PageController _pageController;
  // أثناء الانتقال البرمجي بين التبويبات تمر الصفحة بتبويبات وسيطة؛ نتجاهلها
  // حتى لا تظهر نافذة تسجيل الدخول أو يُعاد تحميل السلة بلا داعٍ.
  bool _animatingToPage = false;

  final _tabs = const [
    HomeTab(),
    OrdersScreen(embedded: true),
    FavoritesScreen(),
    CartScreen(embedded: true),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _destination.index);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (context.read<AuthProvider>().isLoggedIn) {
        context.read<CartProvider>().load();
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cartCount = context.watch<CartProvider>().itemCount;
    final tabs = widget.tabOverrides ?? _tabs;
    // الأخضر الداكن لا يُقرأ فوق سطح داكن، لذا نستخدم الذهبي في الوضع الليلي.
    final selectedColor = Theme.of(context).brightness == Brightness.dark
        ? AppColors.gold
        : AppColors.primary;

    return Scaffold(
      body: PageView(
        controller: _pageController,
        physics: const BouncingScrollPhysics(),
        onPageChanged: (index) {
          if (_animatingToPage) return;
          final target = _MainDestination.values[index];
          final authProvider = context.read<AuthProvider>();
          final cartProvider = context.read<CartProvider>();

          if (target.requiresAuthentication && !authProvider.isLoggedIn) {
            showAuthRequiredDialog(context).then((authenticated) {
              if (!mounted) return;
              if (!authenticated) {
                _pageController.jumpToPage(_destination.index);
              } else {
                setState(() => _destination = target);
                if (target == _MainDestination.cart) {
                  cartProvider.load();
                }
              }
            });
            return;
          }

          setState(() => _destination = target);
          if (target == _MainDestination.cart) {
            cartProvider.load();
          }
        },
        children: tabs,
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.12),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .surface
                      .withValues(alpha: 0.85),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Theme.of(context)
                        .colorScheme
                        .outlineVariant
                        .withValues(alpha: 0.4),
                    width: 1,
                  ),
                ),
                child: NavigationBarTheme(
                  data: NavigationBarThemeData(
                    height: 68,
                    backgroundColor: Colors.transparent,
                    indicatorColor: AppColors.primary.withValues(alpha: 0.15),
                    labelBehavior:
                        NavigationDestinationLabelBehavior.alwaysShow,
                    labelTextStyle: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return TextStyle(
                        color: selected
                            ? selectedColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11,
                        fontWeight:
                            selected ? FontWeight.w700 : FontWeight.w500,
                      );
                    }),
                    iconTheme: WidgetStateProperty.resolveWith((states) {
                      final selected = states.contains(WidgetState.selected);
                      return IconThemeData(
                        color: selected
                            ? selectedColor
                            : Theme.of(context).colorScheme.onSurfaceVariant,
                        size: 23,
                      );
                    }),
                  ),
                  child: NavigationBar(
                    selectedIndex: _destination.index,
                    onDestinationSelected: (index) => _selectDestination(
                      _MainDestination.values[index],
                    ),
                    elevation: 0,
                    backgroundColor: Colors.transparent,
                    destinations: [
                      NavigationDestination(
                        icon: const Icon(Icons.home_outlined),
                        selectedIcon: const Icon(Icons.home_rounded),
                        label:
                            AppLocalizations.of(context).translate('الرئيسية'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.inventory_2_outlined),
                        selectedIcon: const Icon(Icons.inventory_2_rounded),
                        label: AppLocalizations.of(context).translate('طلباتي'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.favorite_border_rounded),
                        selectedIcon: const Icon(Icons.favorite_rounded),
                        label:
                            AppLocalizations.of(context).translate('المفضلة'),
                      ),
                      NavigationDestination(
                        icon: KeyedSubtree(
                          key: CartNavTarget.iconKey,
                          child: Badge(
                            label: AppText('$cartCount'),
                            backgroundColor: AppColors.primary,
                            isLabelVisible: cartCount > 0,
                            child: const Icon(Icons.shopping_cart_outlined),
                          ),
                        ),
                        selectedIcon: Badge(
                          label: AppText('$cartCount'),
                          backgroundColor: AppColors.primary,
                          isLabelVisible: cartCount > 0,
                          child: const Icon(Icons.shopping_cart_rounded),
                        ),
                        label: AppLocalizations.of(context).translate('السلة'),
                      ),
                      NavigationDestination(
                        icon: const Icon(Icons.person_outline_rounded),
                        selectedIcon: const Icon(Icons.person_rounded),
                        label: AppLocalizations.of(context).translate('حسابي'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _selectDestination(_MainDestination destination) async {
    final authProvider = context.read<AuthProvider>();
    if (destination.requiresAuthentication && !authProvider.isLoggedIn) {
      final authenticated = await showAuthRequiredDialog(context);
      if (!mounted || !authenticated) return;
    }

    setState(() => _destination = destination);
    final cartProvider = context.read<CartProvider>();
    _animatingToPage = true;
    final animation = _pageController
        .animateToPage(
          destination.index,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        )
        .whenComplete(() => _animatingToPage = false);
    if (destination == _MainDestination.cart) {
      await cartProvider.load();
    }
    await animation;
  }
}
