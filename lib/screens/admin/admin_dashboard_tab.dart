import '../../theme/theme_switcher.dart';
import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import 'admin_coupon_campaigns_screen.dart';
import 'admin_stories_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_categories_screen.dart';
import 'admin_employees_screen.dart';
import 'admin_accounting_screen.dart';
import 'admin_analytics_screen.dart';
import 'admin_daily_deals_screen.dart';
import 'admin_reports_screen.dart';
import 'admin_shipping_companies_screen.dart';
import 'admin_showcases_screen.dart';
import 'admin_support_screen.dart';
import 'admin_invitations_screen.dart';

class AdminDashboardTab extends StatefulWidget {
  const AdminDashboardTab({super.key, this.service});

  final AdminService? service;

  @override
  State<AdminDashboardTab> createState() => _AdminDashboardTabState();
}

class _AdminDashboardTabState extends State<AdminDashboardTab> {
  late final AdminService _service = widget.service ?? AdminService();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.dashboard();
      setState(() => _data = data);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الإحصائيات.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('لوحة المدير'),
        actions: const [ThemeToggleButton()],
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _buildBody()),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_data == null) {
      return const LoadingIndicator();
    }

    final stats = [
      ('البائعون', '${_data!['sellers_count']}', Icons.storefront),
      ('العملاء', '${_data!['customers_count']}', Icons.people),
      (
        'طلبات بائعين معلّقة',
        '${_data!['pending_sellers_count']}',
        Icons.hourglass_top
      ),
      (
        'منتجات بانتظار المراجعة',
        '${_data!['pending_products_count']}',
        Icons.inventory_2
      ),
      (
        'طلبات سحب معلّقة',
        '${_data!['pending_withdrawals_count']}',
        Icons.payments
      ),
      (
        'إجمالي المبيعات',
        '${_data!['total_sales'].toStringAsFixed(0)} ل.س',
        Icons.trending_up
      ),
      (
        'عمولة المنصة',
        '${_data!['total_commission'].toStringAsFixed(0)} ل.س',
        Icons.account_balance
      ),
    ];

    void open(Widget screen) =>
        Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));

    final groups = <(String, IconData, List<Widget>)>[
      (
        'نظرة عامة',
        Icons.speed_outlined,
        [
          _quickAccessTile(context,
              icon: Icons.insights_outlined,
              label: 'التحليلات',
              primary: true,
              onTap: () => open(const AdminAnalyticsScreen())),
          _quickAccessTile(context,
              icon: Icons.bar_chart_outlined,
              label: 'التقارير',
              onTap: () => open(const AdminReportsScreen())),
        ]
      ),
      (
        'المنتجات والمحتوى',
        Icons.inventory_2_outlined,
        [
          _quickAccessTile(context,
              icon: Icons.category_outlined,
              label: 'الأقسام',
              onTap: () => open(const AdminCategoriesScreen())),
          _quickAccessTile(context,
              icon: Icons.flash_on_outlined,
              label: 'عروض اليوم',
              onTap: () => open(const AdminDailyDealsScreen())),
          _quickAccessTile(context,
              icon: Icons.auto_stories_outlined,
              label: 'الستوري',
              onTap: () => open(const AdminStoriesScreen())),
        ]
      ),
      (
        'التسويق',
        Icons.campaign_outlined,
        [
          _quickAccessTile(context,
              icon: Icons.local_offer_outlined,
              label: 'الكوبونات',
              onTap: () => open(const AdminCouponCampaignsScreen())),
          _quickAccessTile(context,
              icon: Icons.view_carousel_outlined,
              label: 'مساحات العرض',
              onTap: () => open(const AdminShowcasesScreen())),
        ]
      ),
      (
        'المالية',
        Icons.account_balance_wallet_outlined,
        [
          _quickAccessTile(context,
              icon: Icons.account_balance_outlined,
              label: 'المحاسبة',
              onTap: () => open(const AdminAccountingScreen())),
        ]
      ),
      (
        'العمليات والفريق',
        Icons.groups_outlined,
        [
          _quickAccessTile(context,
              icon: Icons.local_shipping_outlined,
              label: 'شركات الشحن',
              onTap: () => open(const AdminShippingCompaniesScreen())),
          _quickAccessTile(context,
              icon: Icons.mark_email_unread_outlined,
              label: 'دعوات الانضمام',
              onTap: () => open(const AdminInvitationsScreen())),
          _quickAccessTile(context,
              icon: Icons.badge_outlined,
              label: 'الموظفون',
              onTap: () => open(const AdminEmployeesScreen())),
          _quickAccessTile(context,
              icon: Icons.support_agent,
              label: 'دعم البائعين',
              onTap: () => open(const AdminSupportScreen())),
          _quickAccessTile(context,
              icon: Icons.settings_outlined,
              label: 'الإعدادات',
              onTap: () => open(const AdminSettingsScreen())),
        ]
      ),
    ];

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final (title, icon, tiles) in groups) ...[
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8, top: 4),
            child: Row(children: [
              Icon(icon, size: 20, color: AppColors.gold),
              const SizedBox(width: 6),
              AppText(title,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 15)),
            ]),
          ),
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            childAspectRatio: 0.85,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            children: tiles,
          ),
          const SizedBox(height: 12),
        ],
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          // ارتفاع ثابت يتسع لعنوان من سطرين (مثل "منتجات بانتظار المراجعة")
          // بدلاً من نسبة أبعاد تضيق على الشاشات الصغيرة
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisExtent: 124,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
          ),
          itemCount: stats.length,
          itemBuilder: (context, index) {
            final (label, value, icon) = stats[index];
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: AppColors.emerald),
                    const SizedBox(height: 6),
                    Flexible(
                      child: AppText(label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 12,
                              height: 1.2)),
                    ),
                    const SizedBox(height: 4),
                    AppText(value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 15)),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _quickAccessTile(BuildContext context,
      {required IconData icon,
      required String label,
      required VoidCallback onTap,
      bool primary = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        decoration: BoxDecoration(
          color: primary
              ? AppColors.emerald
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
              color: primary
                  ? AppColors.emerald
                  : Theme.of(context).colorScheme.outlineVariant),
        ),
        // الأسماء الطويلة (مثل "دعم البائعين") تنقسم لسطرين دون تجاوز البطاقة
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: primary ? Colors.white : AppColors.emerald),
            const SizedBox(height: 4),
            Flexible(
              child: AppText(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12,
                    height: 1.15,
                    color: primary ? Colors.white : null,
                    fontWeight: primary ? FontWeight.bold : null),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
