import '../../services/loyalty_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../providers/auth_provider.dart';
import '../../providers/cart_provider.dart';
import '../../services/checkout_service.dart';
import '../../services/shipping_center_service.dart';
import '../../services/api_exception.dart';
import '../../services/payment_api.dart';
import '../../utils/auth_prompt.dart';
import '../../models/wallet_coupon.dart';
import '../../widgets/coupon_tile.dart';
import '../../widgets/saved_card_picker.dart';
import '../orders/order_detail_screen.dart';
import '../../models/user_address.dart';
import '../../services/address_service.dart';
import '../profile/my_addresses_screen.dart';
import '../../l10n/app_localizations.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _checkoutService = CheckoutService();
  final _paymentApi = PaymentApi();
  late final TextEditingController _nameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _addressController;
  // عناوين الشحن المحفوظة: اختيار أحدها يملأ "عنوان التوصيل" (يبقى قابلاً للتعديل)
  final _addressService = AddressService();
  List<UserAddress> _addresses = const [];
  int? _selectedAddressId;
  String _paymentMethod = 'cash_on_delivery';

  /// طريقة الاستلام: home توصيل للبيت، center استلام من مركز كرم
  String _deliveryMethod = 'home';
  int? _pickupCenterId;
  List<ShippingCenterGroup> _centerGroups = const [];
  bool _centersLoading = false;
  final _centerService = ShippingCenterService();

  /// يظهر خيار البطاقة فقط عندما يكون الدفع الإلكتروني مفعّلاً في السيرفر
  bool _onlineEnabled = false;
  bool _isLoading = false;
  bool _summaryLoading = false;
  bool _paymentInProgress = false;
  String? _paymentStatusText;
  CheckoutSummary? _summary;
  String? _error;
  String? _summaryError;

  /// null = أفضل كوبون تلقائياً، 0 = بلا كوبون، رقم = كوبون اختاره العميل
  int? _couponChoice;

  /// استخدام نقاط الولاء (أقصى ما تسمح به السلة)
  bool _usePoints = false;
  bool _useGiftBalance = true;

  int get _pointsToUse {
    final l = _summary?.loyalty;
    return (_usePoints && l != null && l.usable) ? l.maxUsable : 0;
  }

  String? _couponNotice;

  @override
  void initState() {
    super.initState();
    final user = context.read<AuthProvider>().user;
    _nameController = TextEditingController(text: user?.name ?? '');
    _phoneController = TextEditingController(text: user?.phone ?? '');
    // العنوان المعتمد للشحن أولاً، ثم حقل العنوان القديم في الحساب
    _addressController = TextEditingController(
        text: user?.defaultAddress?.shippingText ?? user?.address ?? '');
    _selectedAddressId = user?.defaultAddress?.id;
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummary());
    _loadAddresses();
    _loadPaymentConfig();
  }

  Future<void> _loadAddresses() async {
    try {
      final list = await _addressService.list();
      if (mounted) setState(() => _addresses = list);
    } catch (_) {
      // العناوين المحفوظة اختيارية؛ يبقى الحقل النصي متاحاً
    }
  }

  void _pickAddress(UserAddress a) {
    setState(() {
      _selectedAddressId = a.id;
      _addressController.text = a.shippingText;
    });
  }

  Future<void> _manageAddresses() async {
    await Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const MyAddressesScreen()));
    await _loadAddresses();
    if (!mounted || _addresses.isEmpty) return;
    // بعد الإدارة: اعتمد العنوان المعتمد الجديد إن لم يُختر عنوان باقٍ
    if (!_addresses.any((a) => a.id == _selectedAddressId)) {
      _pickAddress(_addresses.firstWhere((a) => a.isDefault,
          orElse: () => _addresses.first));
    }
  }

  Future<void> _loadPaymentConfig() async {
    try {
      final config = await _paymentApi.config();
      if (mounted) setState(() => _onlineEnabled = config.onlineEnabled);
    } catch (_) {
      // بدون اتصال: نُبقي الدفع عند الاستلام فقط
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _loadSummary() async {
    setState(() {
      _summaryLoading = true;
      _summaryError = null;
    });
    try {
      final summary = await _checkoutService.summary(
          couponId: _couponChoice, deliveryMethod: _deliveryMethod);
      if (!mounted) return;
      setState(() {
        _summary = summary;
        // بعد رفض استلام طلب: الدفع عند الاستلام ممنوع مؤقتاً
        if (summary.codBlocked && _paymentMethod == 'cash_on_delivery') {
          _paymentMethod = 'card';
        }
        // الكوبون المختار لم يعد صالحاً: نرجع للأفضل تلقائياً بدل أن يعلق العميل
        if (summary.couponDroppedReason != null) {
          _couponNotice =
              'الكوبون الذي اخترته لم يعد صالحاً (${summary.couponDroppedReason}).';
          _couponChoice = null;
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _summaryError = e.message);
    } catch (_) {
      if (mounted) setState(() => _summaryError = 'تعذر تحميل ملخص الدفع.');
    } finally {
      if (mounted) setState(() => _summaryLoading = false);
    }
  }

  Future<void> _setDeliveryMethod(String method) async {
    if (method == _deliveryMethod) return;
    setState(() => _deliveryMethod = method);
    if (method == 'center' && _centerGroups.isEmpty) {
      setState(() => _centersLoading = true);
      try {
        final groups = await _centerService.groups();
        if (mounted) setState(() => _centerGroups = groups);
      } on ApiException catch (e) {
        if (mounted) setState(() => _summaryError = e.message);
      } catch (_) {
        if (mounted) {
          setState(() => _summaryError = 'تعذر تحميل مراكز الشحن.');
        }
      } finally {
        if (mounted) setState(() => _centersLoading = false);
      }
    }
    await _loadSummary();
  }

  Widget _deliveryOption(String method, IconData icon, String title,
      String hint, String currency) {
    final selected = _deliveryMethod == method;
    final fee = _summary?.shippingByMethod[method];
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        key: ValueKey('delivery-$method'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => _setDeliveryMethod(method),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? AppColors.emerald.withValues(alpha: 0.08)
                : Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
                color: selected
                    ? AppColors.emerald
                    : Theme.of(context).colorScheme.outlineVariant,
                width: 1.5),
          ),
          child: Row(children: [
            Icon(selected ? Icons.radio_button_checked : Icons.radio_button_off,
                color: selected ? AppColors.emerald : AppColors.muted, size: 20),
            const SizedBox(width: 10),
            Icon(icon, color: AppColors.emerald),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AppText(title,
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  AppText(hint,
                      style:
                          const TextStyle(fontSize: 12, color: AppColors.muted)),
                ],
              ),
            ),
            if (fee != null)
              AppText(fee == 0 ? 'مجاني' : '${fee.toStringAsFixed(0)} $currency',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
          ]),
        ),
      ),
    );
  }

  Widget _centerPicker() {
    if (_centersLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final items = <DropdownMenuItem<int>>[];
    for (final group in _centerGroups) {
      items.add(DropdownMenuItem<int>(
        enabled: false,
        child: AppText(group.governorateLabel,
            style: const TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.emerald)),
      ));
      for (final c in group.centers) {
        items.add(DropdownMenuItem<int>(
          value: c.id,
          child: Text('${c.name} - ${c.address}',
              overflow: TextOverflow.ellipsis),
        ));
      }
    }
    return DropdownButtonFormField<int>(
      key: const ValueKey('pickup-center'),
      initialValue: _pickupCenterId,
      isExpanded: true,
      items: items,
      decoration: InputDecoration(labelText: context.tr('مركز الاستلام')),
      hint: const AppText('اختر المركز الأقرب لك'),
      onChanged: (v) => setState(() => _pickupCenterId = v),
      validator: (v) => _deliveryMethod == 'center' && v == null
          ? context.tr('اختر مركز الشحن الذي ستستلم منه الطلب.')
          : null,
    );
  }

  /// قائمة كوبونات المحفظة: الصالح مع التوفير، وغير الصالح مع السبب
  Future<void> _pickCoupon() async {
    final options = _summary?.couponOptions ?? const <WalletCoupon>[];
    final current = _summary?.coupon?.id;
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints:
              BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.75),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            children: [
              const AppText('اختر كوبوناً',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              for (final c in options) ...[
                CouponTile(
                  coupon: c,
                  muted: c.ok != true,
                  note: c.ok == true
                      ? (c.id == current
                          ? '✓ مُطبّق'
                          : 'وفّر ${c.saving ?? 0} ل.س')
                      : c.reason,
                  onTap: c.ok == true ? () => Navigator.pop(ctx, c.id) : null,
                ),
                const SizedBox(height: 8),
              ],
              TextButton(
                onPressed: () => Navigator.pop(ctx, 0),
                child: const AppText('إكمال الطلب بدون كوبون'),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _couponChoice = picked;
      _couponNotice = null;
    });
    await _loadSummary();
  }

  Future<void> _submit() async {
    if (!context.read<AuthProvider>().isLoggedIn ||
        context.read<AuthProvider>().user?.role != 'customer') {
      await showAuthRequiredDialog(context);
      return;
    }
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
      _paymentStatusText = null;
    });

    try {
      final order = await _checkoutService.placeOrder(
        shippingName: _nameController.text.trim(),
        shippingPhone: _phoneController.text.trim(),
        shippingAddress: _addressController.text.trim(),
        paymentMethod: _paymentMethod,
        couponId: _couponChoice,
        usePoints: _pointsToUse,
        useGiftBalance: _useGiftBalance && (_summary?.giftBalance ?? 0) > 0,
        deliveryMethod: _deliveryMethod,
        pickupCenterId: _pickupCenterId,
      );

      if (!mounted) return;
      context.read<CartProvider>().clear();

      if (_paymentMethod != 'card' || order.total <= 0) {
        // الدفع عند الاستلام/المحفظة، أو طلب غطّاه رصيد الهدايا: لا نفتح أي صفحة بنك
        await _showInfo(
            title: 'تم إنشاء الطلب',
            message: 'تم استلام طلبك وسنؤكده قريباً.',
            success: true);
        if (mounted) _goToOrder(order.id);
        return;
      }

      await _handlePaymentAfterOrder(order.id,
          amountLabel: '${order.total.toStringAsFixed(0)} ل.س');
    } on ApiException catch (e) {
      if (e.statusCode == 409) {
        // طلب سابق متزامن (ضغطة مكررة أو إعادة إرسال) أنشأ الطلب نفسه: ليس خطأً،
        // فنفرغ السلة ونخبر العميل أن طلبه وصل ولن يتكرر.
        if (!mounted) return;
        context.read<CartProvider>().clear();
        await _showInfo(
            title: 'تم إنشاء الطلب', message: e.message, success: true);
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
        return;
      }
      setState(() {
        _error = e.message;
        // 422 مع كوبون محدد: غالباً لم يعد صالحاً، فنرجع للاختيار التلقائي
        if (e.statusCode == 422 && (_couponChoice ?? 0) > 0) {
          _couponChoice = null;
        }
      });
      _loadSummary();
    } catch (_) {
      setState(() => _error = 'تعذّر إتمام الطلب.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handlePaymentAfterOrder(int orderId,
      {required String amountLabel}) async {
    // بطاقة محفوظة أو بطاقة جديدة في صفحة البنك
    final choice = await chooseCardForPayment(context,
        amountLabel: amountLabel, api: _paymentApi);
    if (!mounted) return;
    if (choice == null) {
      // أغلق نافذة الاختيار: الطلب موجود ويمكنه الدفع لاحقاً من تفاصيل الطلب
      _goToOrder(orderId);
      return;
    }

    setState(() {
      _paymentInProgress = true;
      _paymentStatusText = 'جارٍ بدء عملية الدفع...';
    });
    try {
      final start =
          await _paymentApi.startPayment(orderId, cardId: choice.cardId);
      if (!mounted) return;

      if (start.type == 'paid') {
        await _showInfo(
            title: 'تم الدفع بنجاح',
            message: 'تم خصم المبلغ من بطاقتك وتأكيد طلبك.',
            success: true);
        if (mounted) _goToOrder(orderId);
        return;
      }

      if (start.type == 'failed') {
        await _showInfo(
            title: 'لم تكتمل عملية الدفع',
            message: start.message ??
                'رفض البنك العملية. يمكنك المحاولة ببطاقة أخرى من تفاصيل الطلب.',
            success: false);
        if (mounted) _goToOrder(orderId);
        return;
      }

      if (start.type == 'manual') {
        await _showInfo(
          title: 'تم تأكيد الطلب',
          message:
              start.message ?? 'سيتم الدفع عند الاستلام، وسنؤكد طلبك قريباً.',
          success: true,
        );
        if (!mounted) return;
        _goToOrder(orderId);
        return;
      }

      if (start.type == 'redirect' && (start.url ?? '').isNotEmpty) {
        final opened = await _paymentApi.openCheckout(start.url!);
        if (!mounted) return;
        if (!opened) {
          await _showInfo(
              title: 'تعذّر فتح صفحة الدفع',
              message:
                  'لم نتمكن من فتح صفحة الدفع. يمكنك المحاولة لاحقاً من تفاصيل الطلب.',
              success: false);
          _goToOrder(orderId);
          return;
        }
        setState(() => _paymentStatusText = 'بانتظار تأكيد الدفع من البنك...');
        final status = await _paymentApi.pollStatus(orderId,
            attempts: 20, interval: const Duration(seconds: 3));
        if (!mounted) return;
        if (status.paid) {
          await _showInfo(
              title: 'تم الدفع بنجاح',
              message: 'تم استلام الدفع وتأكيد طلبك.',
              success: true);
        } else if (status.failed) {
          await _showInfo(
              title: 'لم تكتمل عملية الدفع',
              message: 'يمكنك إعادة المحاولة من تفاصيل الطلب.',
              success: false);
        } else {
          await _showInfo(
              title: 'قيد التحقق',
              message:
                  'قد يستغرق التأكيد لحظات. سنوافيك بالنتيجة في تفاصيل الطلب.',
              success: false);
        }
        _goToOrder(orderId);
        return;
      }

      await _showInfo(
          title: 'تم إنشاء الطلب',
          message: start.message ?? 'تم إنشاء الطلب.',
          success: true);
      _goToOrder(orderId);
    } on ApiException catch (e) {
      await _showInfo(title: 'تنبيه الدفع', message: e.message, success: false);
      _goToOrder(orderId);
    } catch (_) {
      await _showInfo(
          title: 'تنبيه الدفع',
          message: 'تعذّر التحقق من الدفع الآن. راجع تفاصيل الطلب.',
          success: false);
      _goToOrder(orderId);
    } finally {
      if (mounted) {
        setState(() {
          _paymentInProgress = false;
          _paymentStatusText = null;
        });
      }
    }
  }

  Future<void> _showInfo(
      {required String title, required String message, required bool success}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: AlertDialog(
          title: AppText(title,
              style: TextStyle(
                  color: success ? AppColors.brandGreen : AppColors.danger)),
          content: AppText(message),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx), child: const AppText('حسناً'))
          ],
        ),
      ),
    );
  }

  void _goToOrder(int orderId) {
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => OrderDetailScreen(orderId: orderId)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.isLoggedIn || auth.user?.role != 'customer') {
      return Scaffold(
        appBar: AppBar(title: const AppText('إتمام الشراء')),
        body: Center(
          child: FilledButton(
            onPressed: () => showAuthRequiredDialog(context),
            child: const AppText('تسجيل الدخول أو إنشاء حساب'),
          ),
        ),
      );
    }

    final cart = context.watch<CartProvider>();
    final summary = _summary;
    final subtotal = summary?.subtotal ?? cart.total;
    final shipping = summary?.shippingFee ?? 150;
    final discount = summary?.discount ?? 0;
    final loyalty = summary?.loyalty;
    final pointsDiscount = _pointsToUse * (loyalty?.pointValue ?? 0);
    final total = (summary?.total ?? (cart.total + 150)) - pointsDiscount;
    final currency = summary?.currency ?? cart.currency;
    // نقطة لكل spendPerPoint مدفوعة فعلاً (بعد الكوبون والنقاط، دون الشحن)
    final willEarn = loyalty == null || !loyalty.enabled
        ? 0
        : ((summary!.subtotal - discount - pointsDiscount) /
                loyalty.spendPerPoint)
            .floor()
            .clamp(0, 1 << 30);

    return Scaffold(
      appBar: AppBar(title: const AppText('إتمام الشراء')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_error != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8)),
                    child: AppText(_error!,
                        style: const TextStyle(color: AppColors.danger)),
                  ),
                const AppText('بيانات الشحن',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  decoration:
                      InputDecoration(labelText: context.tr('الاسم الكامل للاستلام')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: InputDecoration(labelText: context.tr('رقم الهاتف')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null,
                ),
                const SizedBox(height: 16),
                const AppText('طريقة الاستلام',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                _deliveryOption('home', Icons.home_outlined, 'توصيل للبيت',
                    'يصلك المندوب إلى عنوانك', currency),
                _deliveryOption('center', Icons.storefront_outlined,
                    'استلام من مركز شحن', 'تستلمه من مركز كرم الأقرب لك', currency),
                const SizedBox(height: 4),
                if (_deliveryMethod == 'center') _centerPicker(),
                if (_deliveryMethod == 'home' && _addresses.isNotEmpty) ...[
                  const AppText('عناويني المحفوظة',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final a in _addresses)
                        ChoiceChip(
                          key: ValueKey('checkout-address-${a.id}'),
                          selected: a.id == _selectedAddressId,
                          onSelected: (_) => _pickAddress(a),
                          avatar: Icon(
                            {
                                  'home': Icons.home_outlined,
                                  'work': Icons.work_outline,
                                }[a.label] ??
                                Icons.place_outlined,
                            size: 18,
                          ),
                          label: AppText(a.isDefault
                              ? '${a.labelText} - ${a.city} (معتمد)'
                              : '${a.labelText} - ${a.city}'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
                if (_deliveryMethod == 'home')
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: _manageAddresses,
                    icon:
                        const Icon(Icons.edit_location_alt_outlined, size: 18),
                    label: AppText(
                        _addresses.isEmpty ? 'أضف عنوان شحن' : 'إدارة عناويني'),
                  ),
                ),
                if (_deliveryMethod == 'home')
                TextFormField(
                  controller: _addressController,
                  maxLines: 3,
                  decoration:
                      InputDecoration(labelText: context.tr('عنوان التوصيل الكامل')),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null,
                ),
                const SizedBox(height: 20),
                const AppText('طريقة الطلب / الدفع',
                    style: TextStyle(fontWeight: FontWeight.bold)),
                RadioGroup<String>(
                  groupValue: _paymentMethod,
                  onChanged: (v) {
                    if (v != null) setState(() => _paymentMethod = v);
                  },
                  child: Column(
                    children: [
                      if (summary?.codBlocked == true)
                        Container(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                              color: Colors.orange.shade50,
                              borderRadius: BorderRadius.circular(8)),
                          child: AppText(summary!.codBlockedMessage ?? '',
                              style: TextStyle(
                                  color: Colors.orange.shade900, fontSize: 13)),
                        )
                      else
                        const RadioListTile(
                          value: 'cash_on_delivery',
                          title: AppText('الدفع عند الاستلام'),
                          subtitle: AppText('تأكيد يدوي/عند الاستلام',
                              style: TextStyle(fontSize: 12)),
                        ),
                      if (_onlineEnabled)
                        const RadioListTile(
                          value: 'card',
                          title: AppText('بطاقة بنكية (دفع إلكتروني آمن)'),
                          subtitle: AppText(
                              'ادفع ببطاقة محفوظة أو أضف بطاقة في صفحة البنك',
                              style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ),
                if (_paymentInProgress) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                        color: AppColors.brandGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10)),
                    child: Row(children: [
                      const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: AppText(
                              _paymentStatusText ?? 'جارٍ معالجة الدفع...',
                              style: const TextStyle(
                                  color: AppColors.brandGreen))),
                    ]),
                  ),
                ],
                const SizedBox(height: 20),
                if (loyalty != null && loyalty.enabled && loyalty.balance > 0)
                  Card(
                    child: SwitchListTile(
                      value: _usePoints && loyalty.usable,
                      onChanged: loyalty.usable
                          ? (v) => setState(() => _usePoints = v)
                          : null,
                      secondary: const Icon(Icons.diamond_outlined,
                          color: Color(0xFF9A7425)),
                      title: AppText(
                          'استخدم نقاطي (${pointsLabel(loyalty.balance)})',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: AppText(
                        loyalty.usable
                            ? 'خصم حتى ${(loyalty.maxUsable * loyalty.pointValue).toStringAsFixed(0)} $currency (${pointsLabel(loyalty.maxUsable)})'
                            : 'تحتاج ${loyalty.minRedeem} نقاط على الأقل وسلة تكفيها',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                if (loyalty != null && loyalty.enabled && loyalty.balance > 0)
                  const SizedBox(height: 12),
                if ((_summary?.giftBalance ?? 0) > 0) ...[
                  Card(
                    child: SwitchListTile(
                      value: _useGiftBalance,
                      onChanged: (v) => setState(() => _useGiftBalance = v),
                      secondary: const Icon(Icons.card_giftcard_rounded,
                          color: AppColors.emerald),
                      title: AppText(
                          'ادفع من رصيد الهدايا (${_summary!.giftBalance.toStringAsFixed(0)} $currency)',
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: const AppText(
                        'يُخصم من الإجمالي عند تأكيد الطلب، والباقي بطريقة الدفع التي اخترتها.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.confirmation_number_outlined,
                                size: 20),
                            const SizedBox(width: 6),
                            const Expanded(
                                child: AppText('الكوبونات',
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold))),
                            if ((_summary?.couponOptions ?? const [])
                                .isNotEmpty)
                              TextButton(
                                  onPressed:
                                      _summaryLoading ? null : _pickCoupon,
                                  child: AppText(_summary?.coupon == null
                                      ? 'اختيار'
                                      : 'تغيير')),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (_couponNotice != null)
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AppText(_couponNotice!,
                                style: const TextStyle(fontSize: 13)),
                          ),
                        if (_summary?.coupon != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 8),
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: AppText(
                              '${_summary!.couponAuto ? 'طبّقنا لك أفضل كوبون' : 'الكوبون المختار'}: وفّرت ${_summary!.coupon!.saving ?? 0} $currency',
                              style: const TextStyle(
                                  color: AppColors.emerald,
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                          CouponTile(coupon: _summary!.coupon!),
                        ] else
                          AppText(
                            (_summary?.couponOptions ?? const []).isEmpty
                                ? 'لا توجد كوبونات في محفظتك حالياً.'
                                : 'بدون كوبون لهذا الطلب.',
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 13),
                          ),
                        const SizedBox(height: 14),
                        if (_summaryLoading)
                          const Padding(
                            padding: EdgeInsets.only(bottom: 8),
                            child: LinearProgressIndicator(minHeight: 2),
                          ),
                        if (_summaryError != null)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(
                              children: [
                                Expanded(
                                    child: AppText(_summaryError!,
                                        style: const TextStyle(
                                            color: AppColors.danger,
                                            fontSize: 12))),
                                TextButton(
                                    onPressed: _loadSummary,
                                    child: const AppText('تحديث')),
                              ],
                            ),
                          ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText('المجموع الفرعي'),
                            AppText('${subtotal.toStringAsFixed(0)} $currency'),
                          ],
                        ),
                        if (discount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText(
                                  'خصم الكوبون${summary?.coupon?.sourceLabel != null ? ' (${summary!.coupon!.sourceLabel})' : ''}'),
                              AppText('- ${discount.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                      color: Color(0xFF1F7A3A))),
                            ],
                          ),
                        ],
                        if (pointsDiscount > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              AppText('خصم النقاط (${pointsLabel(_pointsToUse)})'),
                              AppText(
                                  '- ${pointsDiscount.toStringAsFixed(0)} $currency',
                                  style: const TextStyle(
                                      color: Color(0xFF1F7A3A))),
                            ],
                          ),
                        ],
                        const SizedBox(height: 6),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            AppText((summary?.parcelCount ?? 1) > 1
                                ? 'رسوم الشحن (${summary!.parcelCount} طرود، طرد من كل متجر)'
                                : 'رسوم الشحن'),
                            if (summary != null &&
                                shipping < summary.baseShippingFee)
                              Text.rich(TextSpan(children: [
                                TextSpan(
                                    text:
                                        '${summary.baseShippingFee.toStringAsFixed(0)} ',
                                    style: const TextStyle(
                                        decoration: TextDecoration.lineThrough,
                                        color: AppColors.muted)),
                                TextSpan(
                                    text: shipping == 0
                                        ? 'مجاني'
                                        : '${shipping.toStringAsFixed(0)} $currency',
                                    style: const TextStyle(
                                        color: Color(0xFF1F7A3A),
                                        fontWeight: FontWeight.bold)),
                              ]))
                            else
                              AppText('${shipping.toStringAsFixed(0)} $currency'),
                          ],
                        ),
                        if (summary?.hasHeavyParcel == true)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: AppText(
                                'طرد وزنه 10 كغ أو أكثر له أجرة شحن أعلى.',
                                style: TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                          ),
                        if ((summary?.shippingDebt ?? 0) > 0) ...[
                          const SizedBox(height: 6),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const AppText('أجرة شحن طلب رفضت استلامه',
                                  style: TextStyle(color: AppColors.danger)),
                              AppText(
                                  '+ ${summary!.shippingDebt.toStringAsFixed(0)} $currency',
                                  style:
                                      const TextStyle(color: AppColors.danger)),
                            ],
                          ),
                        ],
                        const Divider(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const AppText('الإجمالي',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            AppText(
                              '${total.toStringAsFixed(0)} $currency',
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 18),
                            ),
                          ],
                        ),
                        if (willEarn > 0)
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Row(children: [
                              const Icon(Icons.diamond_outlined,
                                  size: 16, color: Color(0xFF9A7425)),
                              const SizedBox(width: 4),
                              AppText(
                                  'ستكسب ${pointsLabel(willEarn)} عند استلام الطلب',
                                  style: const TextStyle(
                                      color: Color(0xFF9A7425), fontSize: 13)),
                            ]),
                          ),
                        if ((summary?.pricingNote ?? '').isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: AppText(summary!.pricingNote!,
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 11)),
                          ),
                        const SizedBox(height: 4),
                        const AppText(
                          'يتم تأكيد الأسعار والكوبون نهائياً عند إنشاء الطلب.',
                          style:
                              TextStyle(color: AppColors.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed:
                      (_isLoading || _paymentInProgress) ? null : _submit,
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.brandGreen,
                      foregroundColor: const Color(0xFFF5ECD2)),
                  child: (_isLoading || _paymentInProgress)
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : AppText(_paymentInProgress
                          ? 'جارٍ التحقق...'
                          : 'تأكيد الطلب والمتابعة للدفع'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
