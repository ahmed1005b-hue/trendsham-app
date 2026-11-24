import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/app_settings_provider.dart';
import '../../theme/theme_switcher.dart';
import '../favorites/favorites_screen.dart';
import '../notifications/notifications_screen.dart';
import '../notifications/notification_settings_screen.dart';
import '../legal/legal_screen.dart';
import '../orders/orders_screen.dart';
import '../chat/chat_screen.dart';
import '../../utils/auth_prompt.dart';
import 'edit_profile_screen.dart';
import 'change_password_screen.dart';
import 'saved_cards_screen.dart';
import '../coupons/my_coupons_screen.dart';
import '../gift_cards/gift_cards_screen.dart';
import '../loyalty/invite_friends_screen.dart';
import '../loyalty/my_points_screen.dart';
import '../returns/returns_screen.dart';
import '../messages/buyer_seller_messages_screen.dart';
import '../../models/user.dart';
import '../../utils/profile_completion.dart';
import 'my_addresses_screen.dart';
import 'account_management_screen.dart';
import '../followed_stores/followed_stores_screen.dart';
import '../../widgets/social_brand.dart';
import '../../services/app_update.dart';
import '../../widgets/accept_invitation_dialog.dart';
import '../seller/seller_support_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final user = auth.user;
    final colorScheme = Theme.of(context).colorScheme;
    // البائع والمدير والموظف لا يشترون: لا تظهر لهم أقسام التسوق
    final isShopper = _isShopper(user);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              // 1. Trendyol Style Top Header
              _buildHeader(context, user),

              const SizedBox(height: 12),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 2. Quick Action Grid (4-Items Row)
                    if (isShopper) ...[
                      _buildQuickActionGrid(context, user),
                      const SizedBox(height: 12),
                    ],

                    // 3. Customer Messages & Stores Row (2 Items)
                    if (user != null && isShopper) ...[
                      _buildSecondaryQuickActions(context, user),
                      const SizedBox(height: 16),
                    ],

                    // 4. "Account" Section Card
                    _buildSectionHeader(context, 'الحساب'),
                    const SizedBox(height: 6),
                    _buildCardWrapper(context, [
                      if (user != null) ...[
                        _buildListTile(
                          context,
                          icon: Icons.person_outline_rounded,
                          iconColor: const Color(0xFF5B67CA),
                          title: 'تعديل البيانات الشخصية',
                          tagPill: !isShopper ||
                                  ProfileCompletion.of(user).isComplete
                              ? null
                              : 'أكمل ملفك التعريفي',
                          tagColor: AppColors.goldInk,
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const EditProfileScreen(),
                            ),
                          ),
                        ),
                        if (isShopper) ...[
                          _buildDivider(context),
                          _buildListTile(
                            context,
                            icon: Icons.location_on_outlined,
                            iconColor: AppColors.brandGreen,
                            title: 'عناويني',
                            tagPill: user.defaultAddress == null
                                ? 'أضف عنوان الشحن'
                                : null,
                            tagColor: AppColors.goldInk,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MyAddressesScreen(),
                              ),
                            ),
                          ),
                        ],
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.lock_outline_rounded,
                          iconColor: const Color(0xFF2CB579),
                          title: 'تغيير كلمة السر',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ChangePasswordScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.manage_accounts_outlined,
                          iconColor: AppColors.danger,
                          title: 'إدارة الحساب',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AccountManagementScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                      ],
                      if (user != null && user.role == 'customer') ...[
                        // البيع والعمل بدعوة من الإدارة فقط: العميل يقبل الدعوة بحسابه هنا
                        _buildListTile(
                          context,
                          icon: Icons.mark_email_unread_outlined,
                          iconColor: const Color(0xFF0B5F4A),
                          title: 'عندك دعوة كبائع أو موظف؟',
                          onTap: () => showAcceptInvitationDialog(context),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.credit_card_rounded,
                          iconColor: const Color(0xFF1A56DB),
                          title: 'بطاقاتي البنكية',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const SavedCardsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.confirmation_number_outlined,
                          iconColor: AppColors.emerald,
                          title: 'كوبوناتي',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyCouponsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.diamond_outlined,
                          iconColor: const Color(0xFF9A7425),
                          title: 'نقاطي',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const MyPointsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.card_giftcard_rounded,
                          iconColor: const Color(0xFFC9962C),
                          title: 'دعوة صديق',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const InviteFriendsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.redeem_rounded,
                          iconColor: AppColors.emerald,
                          title: 'بطاقات الهدايا',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const GiftCardsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.assignment_return_outlined,
                          iconColor: AppColors.danger,
                          title: 'طلبات الإرجاع',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ReturnsScreen(),
                            ),
                          ),
                        ),
                        _buildDivider(context),
                      ],
                      _buildListTile(
                        context,
                        icon: Icons.notifications_none_rounded,
                        iconColor: const Color(0xFFF2994A),
                        title: 'الإشعارات',
                        onTap: () {
                          if (user == null) {
                            showAuthRequiredDialog(context);
                          } else {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NotificationsScreen(),
                              ),
                            );
                          }
                        },
                      ),
                      if (user != null) ...[
                        _buildDivider(context),
                        _buildListTile(
                          context,
                          icon: Icons.tune_rounded,
                          iconColor: const Color(0xFFF2994A),
                          title: 'إعدادات الإشعارات',
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  const NotificationSettingsScreen(),
                            ),
                          ),
                        ),
                      ],
                      _buildDivider(context),
                      _buildListTile(
                        context,
                        icon: Icons.translate_rounded,
                        iconColor: const Color(0xFF2F80ED),
                        title: 'تغيير اللغة',
                        subtitle: _languageName(
                          context.watch<AppSettingsProvider>().locale,
                        ),
                        onTap: () => _chooseLanguage(context),
                      ),
                      _buildDivider(context),
                      _buildListTile(
                        context,
                        icon: Icons.palette_outlined,
                        iconColor: const Color(0xFF9B51E0),
                        title: 'المظهر',
                        subtitle: _themeName(
                          context.watch<ThemeController>().themeMode,
                        ),
                        onTap: () => _chooseTheme(context),
                      ),
                    ]),

                    const SizedBox(height: 16),

                    // 5. "Help & Support" Section Card (العميل: المساعد، البائع: تذاكر الدعم)
                    if (_supportScreen(user) != null) ...[
                      _buildSectionHeader(context, 'المساعدة والاتصال'),
                      const SizedBox(height: 6),
                      _buildCardWrapper(context, [
                        _buildListTile(
                          context,
                          icon: Icons.headset_mic_outlined,
                          iconColor: const Color(0xFF27AE60),
                          title: 'المساعدة والاتصال',
                          onTap: () => _openSupport(context, user),
                        ),
                      ]),
                      const SizedBox(height: 16),
                    ],

                    // 6. "Legal Information" Section Card
                    _buildSectionHeader(context, 'معلومات قانونية'),
                    const SizedBox(height: 6),
                    _buildCardWrapper(context, [
                      _buildListTile(
                        context,
                        icon: Icons.description_outlined,
                        iconColor: const Color(0xFF56CCF2),
                        title: 'الشروط والأحكام',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LegalScreen(type: LegalPageType.terms),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildListTile(
                        context,
                        icon: Icons.privacy_tip_outlined,
                        iconColor: const Color(0xFFEB5757),
                        title: 'سياسة الخصوصية',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                const LegalScreen(type: LegalPageType.privacy),
                          ),
                        ),
                      ),
                      _buildDivider(context),
                      _buildListTile(
                        context,
                        icon: Icons.assignment_return_outlined,
                        iconColor: const Color(0xFFF2994A),
                        title: 'سياسة الإرجاع والاستبدال',
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const LegalScreen(
                                type: LegalPageType.refundPolicy),
                          ),
                        ),
                      ),
                    ]),

                    const SizedBox(height: 24),

                    // حسابات تريندشام على مواقع التواصل (نفس أيقونات أسفل الموقع)
                    const FollowUsSection(),
                    const SizedBox(height: 24),

                    // 7. Logout Button
                    if (user != null)
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            await context.read<AuthProvider>().logout();
                          },
                          icon: const Icon(Icons.logout_rounded,
                              color: AppColors.danger, size: 20),
                          label: const AppText(
                            'تسجيل الخروج',
                            style: TextStyle(
                              color: AppColors.danger,
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 13),
                            side: const BorderSide(
                                color: AppColors.danger, width: 1.5),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            backgroundColor: colorScheme.surface,
                          ),
                        ),
                      ),

                    const SizedBox(height: 16),
                    const AppVersionLabel(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// الزائر والعميل فقط يتسوقون؛ البائع والمدير والموظف حسابات عمل.
  static bool _isShopper(AppUser? user) =>
      user == null || user.role == 'customer';

  /// شاشة الدعم المناسبة للدور، أو null إن لم يكن له دعم (المدير والموظف).
  static Widget? _supportScreen(AppUser? user) => switch (user?.role) {
        null || 'customer' => const ChatScreen(),
        'seller' => const SellerSupportScreen(),
        _ => null,
      };

  void _openSupport(BuildContext context, AppUser? user) {
    final screen = _supportScreen(user);
    if (screen == null) {
      return;
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }

  static String? _roleLabel(String role) => switch (role) {
        'seller' => 'حساب بائع',
        'admin' => 'حساب مدير',
        'employee' => 'حساب موظف',
        _ => null,
      };

  Widget _buildHeader(BuildContext context, AppUser? user) {
    // نسبة إكمال حقيقية من بيانات الحساب؛ للعميل فقط لأنها تشمل عنوان الشحن
    final completion =
        user != null && _isShopper(user) ? ProfileCompletion.of(user) : null;
    final roleLabel = user == null ? null : _roleLabel(user.role);
    final hasSupport = _supportScreen(user) != null;
    return Container(
      width: double.infinity,
      color: AppColors.brandGreen,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: Column(
        children: [
          // Header Top Bar Title & Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                tooltip: context.tr('الإشعارات'),
                icon: const Icon(Icons.notifications_none_rounded,
                    color: Colors.white, size: 24),
                onPressed: () {
                  if (user == null) {
                    showAuthRequiredDialog(context);
                  } else {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const NotificationsScreen(),
                      ),
                    );
                  }
                },
              ),
              const AppText(
                'حسابي',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (hasSupport)
                IconButton(
                  tooltip: context.tr('الدعم'),
                  icon: const Icon(Icons.headset_mic_outlined,
                      color: Colors.white, size: 24),
                  onPressed: () => _openSupport(context, user),
                )
              else
                const SizedBox(width: 48),
            ],
          ),

          const SizedBox(height: 12),

          // User Profile Row
          if (user != null)
            Row(
              children: [
                // الصورة مع حلقة نسبة إكمال الملف الحقيقية
                Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 62,
                      height: 62,
                      child: completion == null
                          ? null
                          : CircularProgressIndicator(
                              value: completion.ratio,
                              strokeWidth: 3.5,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                completion.isComplete
                                    ? const Color(0xFF5CC8A0)
                                    : AppColors.gold,
                              ),
                              semanticsLabel: context.tr('اكتمال الملف الشخصي'),
                              semanticsValue: '${completion.percent}',
                            ),
                    ),
                    ClipOval(
                      child: SizedBox(
                        width: 52,
                        height: 52,
                        child: user.avatarUrl != null
                            ? CachedNetworkImage(
                                imageUrl: user.avatarUrl!,
                                fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(
                                  color: Colors.white,
                                  child: const Icon(Icons.person,
                                      color: AppColors.brandGreen, size: 30),
                                ),
                                placeholder: (_, __) => Container(
                                  color: Colors.white,
                                  child: const Icon(Icons.person,
                                      color: AppColors.brandGreen, size: 30),
                                ),
                              )
                            : Container(
                                color: Colors.white,
                                child: const Icon(Icons.person,
                                    color: AppColors.brandGreen, size: 30),
                              ),
                      ),
                    ),
                    if (completion != null && !completion.isComplete)
                      Positioned(
                        bottom: 0,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.goldInk,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: AppText(
                            // %33 بالعربية والتركية، 33% بالإنكليزية
                            Localizations.localeOf(context).languageCode == 'en'
                                ? '${completion.percent}%'
                                : '%${completion.percent}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppText(
                        user.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AppText(
                        user.email ?? user.phone,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 6),
                      // Pills — Wrap: تنزل الشارة الثانية لسطر جديد إن ضاق المكان
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (roleLabel != null)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: AppText(
                                roleLabel,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          if (user.isVerified)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: Colors.green.shade800,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_circle,
                                      color: Colors.greenAccent, size: 12),
                                  SizedBox(width: 4),
                                  AppText(
                                    'موثّق',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (completion != null && !completion.isComplete)
                            InkWell(
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => completion.onlyAddressMissing
                                      ? const MyAddressesScreen()
                                      : const EditProfileScreen(),
                                ),
                              ),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const AppText(
                                      'أكمل ملفك التعريفي',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    const SizedBox(width: 2),
                                    Icon(
                                      Directionality.of(context) ==
                                              TextDirection.rtl
                                          ? Icons.chevron_left
                                          : Icons.chevron_right,
                                      color: Colors.white,
                                      size: 14,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

          if (user == null)
            Column(
              children: [
                const Icon(Icons.person_outline_rounded,
                    size: 46, color: Colors.white),
                const SizedBox(height: 8),
                const AppText(
                  'تصفّح كضيف',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                const AppText(
                  'سجّل الدخول أو أنشئ حساباً للشراء ومتابعة طلباتك.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.goldInk,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: () => showAuthRequiredDialog(context),
                  child: const AppText('تسجيل الدخول أو إنشاء حساب'),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildQuickActionGrid(BuildContext context, dynamic user) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _gridActionItem(
            context,
            icon: Icons.inventory_2_outlined,
            iconColor: AppColors.goldInk,
            label: 'طلباتي',
            onTap: () {
              if (user == null) {
                showAuthRequiredDialog(context);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const OrdersScreen()),
                );
              }
            },
          ),
          _gridActionItem(
            context,
            icon: Icons.confirmation_number_outlined,
            iconColor: const Color(0xFF27AE60),
            label: 'الكوبونات',
            onTap: () {
              // نفس شاشة "كوبوناتي" في القائمة أدناه؛ الزائر يُطلب منه الدخول كما في "طلباتي"
              if (user == null) {
                showAuthRequiredDialog(context);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const MyCouponsScreen()),
                );
              }
            },
          ),
          _gridActionItem(
            context,
            icon: Icons.favorite_border_rounded,
            iconColor: const Color(0xFFEB5757),
            label: 'المفضلة',
            onTap: () {
              if (user == null) {
                showAuthRequiredDialog(context);
              } else {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const FavoritesScreen()),
                );
              }
            },
          ),
          _gridActionItem(
            context,
            icon: Icons.headset_mic_outlined,
            iconColor: const Color(0xFF2F80ED),
            label: 'مساعد تريندشام',
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ChatScreen()),
            ),
          ),
        ],
      ),
    );
  }

  Widget _gridActionItem(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String label,
    required VoidCallback onTap,
  }) {
    final colorScheme = Theme.of(context).colorScheme;
    // Flexible: الأيقونات الأربع تتقاسم العرض فلا تخرج عن الشاشة مع تكبير الخط
    return Flexible(
        child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 6),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: AppText(
                label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    ));
  }

  Widget _buildSecondaryQuickActions(BuildContext context, dynamic user) {
    return Row(
      children: [
        if (user?.role == 'customer')
          Expanded(
            child: _buildSecondaryTile(
              context,
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: const Color(0xFF9B51E0),
              title: 'مراسلات البائعين',
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => const BuyerSellerMessagesScreen(),
                ),
              ),
            ),
          ),
        if (user?.role == 'customer') const SizedBox(width: 10),
        Expanded(
          child: _buildSecondaryTile(
            context,
            icon: Icons.storefront_outlined,
            iconColor: AppColors.brandGreen,
            title: 'المتاجر التي أتابعها',
            onTap: () {
              if (user == null) {
                showAuthRequiredDialog(context);
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const FollowedStoresScreen()),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSecondaryTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    required VoidCallback onTap,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final colorScheme = Theme.of(context).colorScheme;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
            width: 0.8,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(icon, color: iconColor, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: AppText(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
              ),
            ),
            Icon(
              isRtl ? Icons.chevron_left : Icons.chevron_right,
              color: colorScheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      child: AppText(
        title,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildCardWrapper(BuildContext context, List<Widget> children) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          width: 0.8,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDivider(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Divider(
        height: 1,
        thickness: 0.6,
        color: colorScheme.outlineVariant.withValues(alpha: 0.4));
  }

  Widget _buildListTile(
    BuildContext context, {
    required IconData icon,
    required Color iconColor,
    required String title,
    String? subtitle,
    String? tagPill,
    Color? tagColor,
    required VoidCallback onTap,
  }) {
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final colorScheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Row(
        children: [
          Expanded(
            child: AppText(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: colorScheme.onSurface,
              ),
            ),
          ),
          if (tagPill != null)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: (tagColor ?? AppColors.goldInk).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: AppText(
                tagPill,
                style: TextStyle(
                  color: tagColor ?? AppColors.goldInk,
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
      subtitle: subtitle != null
          ? AppText(
              subtitle,
              style:
                  TextStyle(fontSize: 12, color: colorScheme.onSurfaceVariant),
            )
          : null,
      trailing: Icon(
        isRtl ? Icons.chevron_left : Icons.chevron_right,
        color: colorScheme.onSurfaceVariant,
        size: 20,
      ),
      onTap: onTap,
    );
  }

  String _languageName(Locale locale) => switch (locale.languageCode) {
        'en' => 'الإنجليزية',
        'tr' => 'التركية',
        _ => 'العربية',
      };

  String _themeName(ThemeMode mode) => switch (mode) {
        ThemeMode.light => 'فاتح',
        ThemeMode.dark => 'داكن',
        ThemeMode.system => 'حسب الجهاز',
      };

  void _chooseLanguage(BuildContext context) {
    final current = context.read<AppSettingsProvider>().locale;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppText(
                'تغيير اللغة',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            RadioGroup<Locale>(
              groupValue: current,
              onChanged: (value) {
                context.read<AppSettingsProvider>().setLocale(value!);
                Navigator.pop(sheetContext);
              },
              child: Column(
                children: [
                  for (final locale in AppLocalizations.supportedLocales)
                    RadioListTile<Locale>(
                      value: locale,
                      title: AppText(_languageName(locale)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _chooseTheme(BuildContext context) {
    final current = context.read<ThemeController>().themeMode;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: AppText(
                'المظهر',
                style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Theme.of(context).colorScheme.onSurface),
              ),
            ),
            RadioGroup<ThemeMode>(
              groupValue: current,
              onChanged: (value) {
                context.read<ThemeController>().setThemeMode(value!);
                Navigator.pop(sheetContext);
              },
              child: Column(
                children: [
                  for (final mode in ThemeMode.values)
                    RadioListTile<ThemeMode>(
                      value: mode,
                      title: AppText(_themeName(mode)),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
