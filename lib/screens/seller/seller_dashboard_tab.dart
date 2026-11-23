import '../../theme/theme_switcher.dart';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/seller_profile.dart';
import '../../models/product.dart';
import '../../services/seller_service.dart';
import '../../services/seller_return_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/attribution_metrics_card.dart';
import '../../widgets/product_card.dart';
import 'seller_stories_screen.dart';
import 'seller_daily_deals_screen.dart';
import 'seller_coupons_screen.dart';
import 'seller_products_screen.dart';
import 'seller_orders_screen.dart';
import 'seller_wallet_screen.dart';
import 'seller_support_screen.dart';
import 'seller_stock_screen.dart';
import 'seller_charts.dart';
import 'seller_store_profile_screen.dart';
import 'seller_questions_screen.dart';
import 'seller_showcases_screen.dart';
import 'seller_returns_screen.dart';
import 'seller_shipping_settings_screen.dart';
import 'seller_analytics_screen.dart';
import '../messages/buyer_seller_messages_screen.dart';

class SellerDashboardTab extends StatefulWidget {
  const SellerDashboardTab({super.key});

  @override
  State<SellerDashboardTab> createState() => _SellerDashboardTabState();
}

class _SellerDashboardTabState extends State<SellerDashboardTab> {
  final SellerService _service = SellerService();
  final SellerReturnService _returnService = SellerReturnService();
  int _requestedReturns = 0;
  final ImagePicker _imagePicker = ImagePicker();
  Map<String, dynamic>? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    _loadRequestedReturns();
    try {
      final data = await _service.dashboard();
      if (!mounted) return;
      setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل لوحتك.');
    }
  }

  /// عدد طلبات الإرجاع بانتظار الرد؛ فشله لا يعطّل اللوحة.
  Future<void> _loadRequestedReturns() async {
    try {
      final count = await _returnService.requestedCount();
      if (mounted) setState(() => _requestedReturns = count);
    } catch (_) {}
  }

  Future<void> _openReturns() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const SellerReturnsScreen()));
    if (mounted) _loadRequestedReturns();
  }

  Future<void> _submitIdentityDocument() async {
    final selected = await _imagePicker.pickImage(source: ImageSource.gallery);
    if (selected == null) return;

    final extension = selected.name.split('.').last.toLowerCase();
    if (!{'jpg', 'jpeg', 'png', 'webp'}.contains(extension) ||
        await File(selected.path).length() > 5 * 1024 * 1024) {
      try {
        await File(selected.path).delete();
      } catch (_) {}
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                AppText('اختر JPG أو PNG أو WEBP بحجم لا يتجاوز 5 ميغابايت.'),
          ),
        );
      }
      return;
    }

    try {
      await _service.submitIdentityDocument(selected);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم إرسال صورة الهوية للمراجعة.')),
      );
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تعذّر إرسال صورة الهوية.')),
        );
      }
    } finally {
      try {
        final file = File(selected.path);
        if (await file.exists()) await file.delete();
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('لوحة إحصائيات البائع',
            overflow: TextOverflow.ellipsis),
        actions: [
          const ThemeToggleButton(),
          IconButton(
            tooltip: context.tr('الرسائل'),
            icon: const Icon(Icons.chat_bubble_outline),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => const BuyerSellerMessagesScreen())),
          ),
          IconButton(
            tooltip: context.tr('تحديث'),
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
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
        message: _error!,
        icon: Icons.error_outline,
        onRetry: _load,
      );
    }
    if (_data == null) {
      return const LoadingIndicator();
    }

    final store = _data!['store'] as SellerProfileModel;
    final double totalSales =
        double.tryParse((_data!['total_sales'] ?? 0).toString()) ?? 0;
    final int ordersCount = (dataValue('orders_count') as num?)?.toInt() ?? 0;
    final double commissionAmount =
        double.tryParse((_data!['commission_amount'] ?? 0).toString()) ??
            (totalSales * store.commissionRate / 100);
    final double netProfit =
        double.tryParse((_data!['net_profit'] ?? 0).toString()) ??
            (totalSales - commissionAmount);
    final double walletBalance =
        double.tryParse((_data!['wallet_balance'] ?? 0).toString()) ?? 0;
    final int productsCount =
        (dataValue('products_count') as num?)?.toInt() ?? 0;
    final int pendingProductsCount =
        (dataValue('pending_products_count') as num?)?.toInt() ?? 0;

    final List<Product> topProducts =
        (_data!['top_products'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
            .toList();
    final List<Map<String, dynamic>> weeklySales =
        (_data!['weekly_sales'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    final List<Map<String, dynamic>> monthlySales =
        (_data!['monthly_sales'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();
    final double? monthlyGrowth = _data!['monthly_growth'] is num
        ? (_data!['monthly_growth'] as num).toDouble()
        : null;
    final int totalViews = (_data!['total_views'] as num?)?.toInt() ?? 0;
    final int convertedVisits =
        (_data!['attributed_converting_visits'] as num?)?.toInt() ?? 0;
    final int attributedOrders =
        (_data!['attributed_orders'] as num?)?.toInt() ?? 0;
    final double conversionRate =
        (_data!['conversion_rate'] as num?)?.toDouble() ?? 0;
    final double? sellerRating = _data!['seller_rating'] is num
        ? (_data!['seller_rating'] as num).toDouble()
        : null;
    final int sellerReviewsCount =
        (_data!['seller_reviews_count'] as num?)?.toInt() ?? 0;
    final List<Map<String, dynamic>> lowStockProducts =
        (_data!['low_stock_products'] as List<dynamic>? ?? [])
            .whereType<Map>()
            .map((row) => Map<String, dynamic>.from(row))
            .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // بطاقة التعريف بالمتجر ونسبة العمولة
        _buildStoreHeaderCard(store),
        const SizedBox(height: 16),
        // تنبيه المخزون المنخفض
        if (lowStockProducts.isNotEmpty) ...[
          LowStockAlertCard(
            products: lowStockProducts,
            onManage: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SellerStockScreen()),
            ),
          ),
          const SizedBox(height: 16),
        ],
        // الزيارات وتقييم المتجر
        SellerStatsRow(
          totalViews: totalViews,
          sellerRating: sellerRating,
          sellerReviewsCount: sellerReviewsCount,
        ),
        const SizedBox(height: 8),
        AttributionMetricsCard(
          totalVisits: totalViews,
          convertingVisits: convertedVisits,
          attributedOrders: attributedOrders,
          conversionRate: conversionRate,
        ),
        const SizedBox(height: 16),
        // مخطط المبيعات الأسبوعي/الشهري
        SalesChartCard(
          weeklySales: weeklySales,
          monthlySales: monthlySales,
          monthlyGrowth: monthlyGrowth,
        ),
        const SizedBox(height: 16),

        // إحصائيات المبيعات والأرباح والطلبات
        const Row(
          children: [
            Icon(Icons.analytics_outlined, color: AppColors.emerald, size: 20),
            SizedBox(width: 8),
            AppText(
              'المؤشرات المالية والمبيعات',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),

        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 1.35,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _statCard(
              'إجمالي المبيعات',
              '${totalSales.toStringAsFixed(0)} ل.س',
              Icons.trending_up,
              color: Colors.blue.shade700,
              bgColor: context.softTint(Colors.blue),
            ),
            _statCard(
              'إجمالي الطلبات',
              '$ordersCount طلب',
              Icons.shopping_bag_outlined,
              color: Colors.purple.shade700,
              bgColor: Colors.purple.shade50,
            ),
            _statCard(
              'عمولة المنصة (${store.commissionRate}%)',
              '${commissionAmount.toStringAsFixed(0)} ل.س',
              Icons.account_balance,
              color: Colors.orange.shade800,
              bgColor: context.softTint(Colors.orange),
            ),
            _statCard(
              'صافي الأرباح',
              '${netProfit.toStringAsFixed(0)} ل.س',
              Icons.monetization_on_outlined,
              color: AppColors.emerald,
              bgColor: context.softTint(AppColors.emerald),
            ),
            _statCard(
              'رصيد المحفظة',
              '${walletBalance.toStringAsFixed(0)} ل.س',
              Icons.account_balance_wallet_outlined,
              color: Colors.teal.shade700,
              bgColor: Colors.teal.shade50,
            ),
            _statCard(
              'عدد المنتجات',
              '$productsCount منتج',
              Icons.inventory_2_outlined,
              color: Colors.indigo.shade700,
              bgColor: Colors.indigo.shade50,
            ),
          ],
        ),
        const SizedBox(height: 20),

        // تنبيه المنتجات قيد المراجعة
        if (pendingProductsCount > 0) ...[
          Card(
            color: context.softTint(Colors.amber),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.amber.shade300),
            ),
            child: ListTile(
              leading: const Icon(Icons.hourglass_top_rounded,
                  color: AppColors.gold),
              title: AppText(
                '$pendingProductsCount منتج بانتظار موافقة الإدارة',
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              subtitle: const AppText(
                'سيتم إشعارك فور مراجعة المنتجات واعتمادها.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // قسم المنتجات الأكثر مشاهدة ومبيعاً
        const Row(
          children: [
            Icon(Icons.local_fire_department,
                color: Colors.deepOrange, size: 20),
            SizedBox(width: 8),
            AppText(
              'المنتجات الأكثر مشاهدة ومبيعاً',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        _buildTopProductsSection(topProducts),
        const SizedBox(height: 20),

        // اختصارات وإدارة المتجر
        const Row(
          children: [
            Icon(Icons.grid_view_rounded, color: AppColors.emerald, size: 20),
            SizedBox(width: 8),
            AppText(
              'إدارة المتجر والسحب',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 2,
          childAspectRatio: 2.2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          children: [
            _quickTile(
              context,
              icon: Icons.inventory_2_outlined,
              title: 'المنتجات',
              subtitle: 'إدارة وتعديل المنتجات',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerProductsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.shopping_bag_outlined,
              title: 'الطلبات',
              subtitle: 'متابعة الطلبات الواردة',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerOrdersScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.insights_outlined,
              title: 'مؤشرات الأداء',
              subtitle: 'المبيعات والدخل بالتفصيل',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerAnalyticsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.local_shipping_outlined,
              title: 'إعدادات الشحن',
              subtitle: 'من يوصل طلباتك وبكم',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerShippingSettingsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.account_balance_wallet_outlined,
              title: 'المحفظة والسحب',
              subtitle: 'سحب الأرباح ورصيدك',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerWalletScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.auto_stories_outlined,
              title: 'الستوري',
              subtitle: 'نشر ستوري ترويجية',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerStoriesScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.confirmation_number_outlined,
              title: 'الكوبونات',
              subtitle: 'كوبونات خصم لمتجرك',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerCouponsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.local_offer_outlined,
              title: 'عروض اليوم',
              subtitle: 'خصومات يومية على منتجاتك',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerDailyDealsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.headset_outlined,
              title: 'الدعم الفني',
              subtitle: 'تواصل مع الإدارة',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const SellerSupportScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.question_answer_outlined,
              title: 'أسئلة العملاء',
              subtitle: 'الرد على أسئلة منتجاتك',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerQuestionsScreen()),
              ),
            ),
            _quickTile(
              context,
              icon: Icons.assignment_return_outlined,
              title: 'طلبات الإرجاع',
              subtitle: 'الرد على طلبات إرجاع المنتجات',
              badgeCount: _requestedReturns,
              onTap: _openReturns,
            ),
            _quickTile(
              context,
              icon: Icons.view_carousel_outlined,
              title: 'مساحات العرض',
              subtitle: 'إعلان متجرك في الرئيسية',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                    builder: (_) => const SellerShowcasesScreen()),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  dynamic dataValue(String key) => _data?[key];

  Future<void> _editStoreProfile(SellerProfileModel store) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => SellerStoreProfileScreen(store: store),
      ),
    );
    if (!mounted) return;
    if (updated == true) _load();
  }

  Widget _buildTopProductsSection(List<Product> products) {
    if (products.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        alignment: Alignment.center,
        child: const AppText('لا توجد منتجات مسجلة بعد.',
            style: TextStyle(color: AppColors.muted)),
      );
    }
    return SizedBox(
      height: 280,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: products.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final p = products[index];
          return SizedBox(
            width: 165,
            child: ProductCard(
              product: p,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const SellerProductsScreen(),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildStoreHeaderCard(SellerProfileModel store) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: context.softTint(AppColors.emerald),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.storefront,
                      color: AppColors.emerald, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        store.storeName,
                        style: const TextStyle(
                            fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const AppText('حالة الحساب: ',
                              style: TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            label: AppText(
                              store.statusLabel,
                              style: const TextStyle(fontSize: 11),
                            ),
                            backgroundColor: store.status == 'approved'
                                ? AppColors.emerald.withValues(alpha: .15)
                                : store.status == 'rejected'
                                    ? Colors.red.withValues(alpha: .1)
                                    : Colors.amber.withValues(alpha: .2),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _editStoreProfile(store),
                icon: const Icon(Icons.edit_outlined),
                label: const AppText('تعديل واجهة المتجر'),
              ),
            ),
            if (store.status == 'approved') ...[
              const Divider(height: 16, thickness: 0.8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const AppText(
                    'نسبة عمولة المنصة المتفق عليها:',
                    style: TextStyle(color: AppColors.muted, fontSize: 12),
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: AppText(
                      '%${store.commissionRate}',
                      style: const TextStyle(
                          color: AppColors.emerald,
                          fontWeight: FontWeight.bold,
                          fontSize: 12),
                    ),
                  ),
                ],
              ),
            ],
            if (store.status == 'rejected' &&
                store.rejectionReason != null) ...[
              const SizedBox(height: 6),
              AppText(
                'سبب الرفض: ${store.rejectionReason}',
                style: const TextStyle(color: AppColors.danger, fontSize: 12),
              ),
            ],
            if (store.status != 'approved') ...[
              const SizedBox(height: 8),
              AppText(
                store.hasIdentityDocument
                    ? 'تم استلام صورة الهوية. سيبقى النشر متوقفاً حتى اعتماد المتجر.'
                    : 'يلزم إرسال صورة الهوية قبل مراجعة الطلب واعتماد المتجر.',
                style: const TextStyle(color: AppColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _submitIdentityDocument,
                  icon: const Icon(Icons.badge_outlined),
                  label: AppText(store.hasIdentityDocument
                      ? 'استبدال صورة الهوية وإعادة الإرسال'
                      : 'إرسال صورة الهوية للمراجعة'),
                ),
              ),
              const AppText(
                'JPG أو PNG أو WEBP، بحد أقصى 5 ميغابايت. الوثيقة متاحة للإدارة فقط.',
                style: TextStyle(color: AppColors.muted, fontSize: 11),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _statCard(
    String label,
    String value,
    IconData icon, {
    required Color color,
    required Color bgColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: bgColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 8),
          AppText(
            label,
            style: const TextStyle(color: AppColors.muted, fontSize: 11),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          AppText(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 15,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _quickTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    String? subtitle,
    int badgeCount = 0,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: context.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.emerald, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12.5,
                      color: AppColors.darkInk,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    AppText(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.muted,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (badgeCount > 0)
              Badge(
                label: Text('$badgeCount'),
                backgroundColor: AppColors.danger,
              ),
          ],
        ),
      ),
    );
  }
}
