import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../theme/theme_switcher.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/order.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/api_exception.dart';
import '../../services/checkout_service.dart';
import '../../utils/auth_prompt.dart';
import '../../widgets/app_state_message.dart';
import '../chat/chat_screen.dart';
import '../notifications/notifications_screen.dart';
import 'order_detail_screen.dart';
import '../../widgets/brand_wordmark.dart';

class OrdersScreen extends StatefulWidget {
  final bool embedded;

  const OrdersScreen({super.key, this.embedded = false});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  Widget paymentBadge(String? status) {
    final st = (status ?? 'none').toLowerCase();
    Color bg;
    Color fg;
    String label;
    IconData icon;
    if (st == 'paid') {
      bg = Colors.green.withValues(alpha: 0.12);
      fg = Colors.green.shade700;
      label = 'مدفوع';
      icon = Icons.verified_rounded;
    } else if (st == 'failed' || st == 'cancelled') {
      bg = AppColors.danger.withValues(alpha: 0.12);
      fg = AppColors.danger;
      label = st == 'cancelled' ? 'ملغي الدفع' : 'فشل الدفع';
      icon = Icons.error_outline;
    } else {
      bg = const Color(0xFFF2994A).withValues(alpha: 0.12);
      fg = const Color(0xFFB96A1A);
      label = 'غير مدفوع';
      icon = Icons.payments_outlined;
    }
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration:
            BoxDecoration(color: bg, borderRadius: BorderRadius.circular(20)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, color: fg, size: 12),
          const SizedBox(width: 4),
          AppText(label,
              style: TextStyle(
                  color: fg, fontSize: 11, fontWeight: FontWeight.bold))
        ]));
  }

  final OrderService _orderService = OrderService();
  List<Order>? _orders;
  String? _error;
  bool _initialLoadStarted = false;
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
    if (context.read<AuthProvider>().isLoggedIn) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() => _error = null);
    try {
      final orders = await _orderService.list();
      if (!mounted) return;
      setState(() => _orders = orders);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'تعذّر تحميل الطلبات.');
    }
  }

  List<Order> get _filteredOrders {
    if (_orders == null) return [];
    if (_selectedFilter == 'all') return _orders!;
    return _orders!.where((o) {
      final s = o.status.toLowerCase();
      if (_selectedFilter == 'processing') {
        return s == 'processing' || s == 'paid';
      }
      if (_selectedFilter == 'shipped') {
        return s == 'shipped' || s == 'in_transit';
      }
      return s == _selectedFilter;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = context.watch<AuthProvider>().isLoggedIn;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (!isLoggedIn) {
      return Scaffold(
        appBar: widget.embedded ? null : AppBar(title: const AppText('طلباتي')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.lock_outline,
                    size: 48, color: AppColors.primary),
                const SizedBox(height: 12),
                const AppText('سجّل الدخول لمتابعة طلباتك.',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => showAuthRequiredDialog(context),
                  icon: const Icon(Icons.login_rounded),
                  label: const AppText('تسجيل الدخول أو إنشاء حساب'),
                  style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (!_initialLoadStarted) {
      _initialLoadStarted = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _load();
      });
    }

    final totalCount = _orders?.length ?? 0;

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _load,
          color: AppColors.brandGreen,
          child: Column(
            children: [
              // رأسية الصفحة المماثلة للشاشة الرئيسية
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    const Flexible(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: AlignmentDirectional.centerStart,
                        child: BrandWordmark(),
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ChatScreen()),
                      ),
                      tooltip: context.tr('خدمة العملاء'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.support_agent_rounded,
                          color: isDark
                              ? const Color(0xFF8CCFB4)
                              : AppColors.brandGreen,
                          size: 23),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const NotificationsScreen()),
                      ),
                      tooltip: context.tr('الإشعارات'),
                      visualDensity: VisualDensity.compact,
                      icon: Icon(Icons.notifications_none_rounded,
                          color: isDark
                              ? const Color(0xFF8CCFB4)
                              : AppColors.brandGreen,
                          size: 23),
                    ),
                    const SizedBox(width: 4),
                    Consumer<ThemeController>(
                      builder: (context, themeController, _) {
                        return IconButton(
                          onPressed: () => themeController.toggleTheme(),
                          tooltip: isDark ? 'الوضع النهاري' : 'الوضع الليلي',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                              isDark
                                  ? Icons.wb_sunny_rounded
                                  : Icons.dark_mode_rounded,
                              color: isDark
                                  ? const Color(0xFF8CCFB4)
                                  : AppColors.brandGreen,
                              size: 23),
                        );
                      },
                    ),
                  ],
                ),
              ),

              // شريط إحصائي علوي أنيق
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(14, 4, 14, 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppColors.brandGreen,
                      AppColors.brandGreen.withValues(alpha: 0.85),
                    ],
                    begin: Alignment.centerRight,
                    end: Alignment.centerLeft,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.brandGreen.withValues(alpha: 0.15),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.local_shipping_rounded,
                          color: Colors.white, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppText(
                            'تتبع مشترياتك وطلباتك بكل سهولة',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          AppText(
                            _orders == null
                                ? 'جارِ التحميل...'
                                : 'لديك إجمالي $totalCount طلب مسجل',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.verified_rounded,
                        color: AppColors.gold, size: 22),
                  ],
                ),
              ),
              _buildFilterTabs(),
              Expanded(child: _buildBody()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterTabs() {
    final filters = [
      {'key': 'all', 'label': 'الكل', 'color': AppColors.primary},
      {
        'key': 'processing',
        'label': 'قيد المراجعة',
        'color': const Color(0xFF2F80ED)
      },
      {'key': 'shipped', 'label': 'قيد الشحن', 'color': AppColors.primary},
      {
        'key': 'delivered',
        'label': 'تم التسليم',
        'color': Colors.green.shade700
      },
      {'key': 'cancelled', 'label': 'ملغي', 'color': AppColors.danger},
    ];

    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        itemCount: filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final filter = filters[index];
          final isSelected = _selectedFilter == filter['key'];
          final color = filter['color'] as Color;

          return ActionChip(
            onPressed: () =>
                setState(() => _selectedFilter = filter['key'] as String),
            label: AppText(filter['label'] as String),
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: isSelected
                  ? Colors.white
                  : Theme.of(context).colorScheme.onSurface,
            ),
            backgroundColor:
                isSelected ? color : Theme.of(context).colorScheme.surface,
            side: BorderSide(
              color: isSelected ? color : color.withValues(alpha: 0.35),
            ),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          );
        },
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
        message: _error!,
        icon: Icons.error_outline,
        onRetry: _load,
      );
    }
    if (_orders == null) {
      return const LoadingIndicator();
    }
    final list = _filteredOrders;
    if (list.isEmpty) {
      return const AppStateMessage(
        message: 'لا توجد طلبات مطابقة لهذه الحالة.',
        icon: Icons.receipt_long_outlined,
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 96),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        return _buildOrderCard(context, list[index]);
      },
    );
  }

  Widget _buildOrderCard(BuildContext context, Order order) {
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    Color statusColor;
    Color statusBgColor;
    IconData statusIcon;

    switch (order.status) {
      case 'delivered':
        statusColor = Colors.green.shade700;
        statusBgColor = Colors.green.withValues(alpha: 0.12);
        statusIcon = Icons.check_circle_outline_rounded;
        break;
      case 'shipped':
      case 'in_transit':
        statusColor = AppColors.primary;
        statusBgColor = AppColors.primary.withValues(alpha: 0.12);
        statusIcon = Icons.local_shipping_outlined;
        break;
      case 'processing':
      case 'paid':
        statusColor = const Color(0xFF2F80ED);
        statusBgColor = const Color(0xFF2F80ED).withValues(alpha: 0.12);
        statusIcon = Icons.inventory_2_outlined;
        break;
      case 'cancelled':
        statusColor = AppColors.danger;
        statusBgColor = AppColors.danger.withValues(alpha: 0.12);
        statusIcon = Icons.cancel_outlined;
        break;
      default:
        statusColor = const Color(0xFFF2994A);
        statusBgColor = const Color(0xFFF2994A).withValues(alpha: 0.12);
        statusIcon = Icons.hourglass_top_rounded;
    }

    final dateString = order.createdAt != null
        ? '${order.createdAt!.year}/${order.createdAt!.month.toString().padLeft(2, '0')}/${order.createdAt!.day.toString().padLeft(2, '0')}'
        : '';

    String cityName = '';
    final address = order.shippingAddress.trim();
    if (address.isNotEmpty) {
      final parts = address.split(RegExp(r'[,،-]'));
      if (parts.isNotEmpty) {
        cityName = parts.last.trim();
      }
      if (cityName.isEmpty) {
        cityName = address;
      }
    }

    final itemCount = order.effectiveItemsCount;

    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => OrderDetailScreen(orderId: order.id),
          ),
        ),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // الصف الأول: رقم الطلب والتاريخ (يسار) | حالة الطلب (يمين)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(
                          'طلب #${order.orderNumber}',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: colorScheme.onSurface,
                          ),
                        ),
                        if (dateString.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          AppText(
                            dateString,
                            style: TextStyle(
                              fontSize: 11,
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 4),
                        paymentBadge(order.paymentStatus),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusBgColor,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(statusIcon, color: statusColor, size: 14),
                        const SizedBox(width: 4),
                        AppText(
                          order.statusLabel,
                          style: TextStyle(
                            color: statusColor,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 12),

              // الصف الثاني: السعر الإجمالي (يسار) | عدد المنتجات والمدينة (يمين)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (itemCount > 0)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Row(
                            children: [
                              Icon(Icons.shopping_bag_outlined,
                                  size: 14,
                                  color: colorScheme.onSurfaceVariant),
                              const SizedBox(width: 4),
                              AppText(
                                '$itemCount منتجات',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                      if (cityName.isNotEmpty || order.shippingName.isNotEmpty)
                        Row(
                          children: [
                            Icon(Icons.location_on_outlined,
                                size: 14, color: colorScheme.onSurfaceVariant),
                            const SizedBox(width: 4),
                            AppText(
                              cityName.isNotEmpty
                                  ? cityName
                                  : order.shippingName,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: AlignmentDirectional.centerEnd,
                      child: AppText(
                        '${order.total.toStringAsFixed(0)} ل.س',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                          color: isDark ? AppColors.gold : AppColors.brandGreen,
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              if (order.trackingNumber != null &&
                  order.trackingNumber!.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                        color: AppColors.primary.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.local_shipping_outlined,
                          color: AppColors.primary, size: 15),
                      const SizedBox(width: 5),
                      Expanded(
                        child: AppText(
                          'تتبع الشحنة: ${order.trackingNumber}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          Clipboard.setData(
                              ClipboardData(text: order.trackingNumber!));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: AppText('تم نسخ رقم التتبع بنجاح!'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Padding(
                          padding:
                              EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(Icons.copy_rounded,
                              color: AppColors.primary, size: 15),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),
              Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.4)),
              const SizedBox(height: 8),

              // زر تفاصيل الطلب وإعادة الطلب
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  ElevatedButton.icon(
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final cartProvider = context.read<CartProvider>();
                      int addedCount = 0;
                      for (final item in order.items) {
                        if (item.productId != null) {
                          await cartProvider.add(item.productId!,
                              quantity: item.quantity);
                          addedCount++;
                        }
                      }
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: AppText(addedCount > 0
                              ? 'تمت إضافة عناصر الطلب إلى سلتك بنجاح!'
                              : 'تعذّر إعادة إضافة عناصر هذا الطلب.'),
                          backgroundColor: AppColors.brandGreen,
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 14),
                    label: const AppText('إعادة الطلب',
                        style: TextStyle(
                            fontSize: 11, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark
                          ? AppColors.brandGreenLight
                          : AppColors.brandGreen,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => OrderDetailScreen(orderId: order.id),
                      ),
                    ),
                    icon: const Icon(Icons.visibility_outlined, size: 15),
                    label: const AppText('تفاصيل الطلب',
                        style: TextStyle(
                            fontSize: 11.5, fontWeight: FontWeight.bold)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isDark
                          ? const Color(0xFF8CCFB4)
                          : AppColors.brandGreen,
                      side: BorderSide(
                        color: isDark
                            ? const Color(0xFF8CCFB4).withValues(alpha: 0.5)
                            : AppColors.brandGreen.withValues(alpha: 0.5),
                      ),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
