import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/store_shipping_service.dart';
import '../../widgets/app_state_message.dart';

/// إعدادات شحن المتجر (نفس صفحة الموقع): من يوصل الطلبات، وبكم لكل محافظة،
/// والشحن المجاني، ومدة التجهيز والتوصيل، والاستلام من المحل، ودين المتجر.
class SellerShippingSettingsScreen extends StatefulWidget {
  const SellerShippingSettingsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final StoreShippingService? service;

  @override
  State<SellerShippingSettingsScreen> createState() =>
      _SellerShippingSettingsScreenState();
}

class _SellerShippingSettingsScreenState
    extends State<SellerShippingSettingsScreen> {
  late final StoreShippingService _service =
      widget.service ?? StoreShippingService();
  final _money = NumberFormat.decimalPattern('en');
  final _freeOver = TextEditingController();
  final _pickupAddress = TextEditingController();
  final _samePrice = TextEditingController();
  final Map<String, TextEditingController> _fees = {};

  StoreShippingSettings? _settings;
  String? _loadError;
  String? _saveError;
  bool _saving = false;

  static const _deliveryDays = {
    0: 'في نفس اليوم',
    1: 'يوم واحد',
    2: 'يومان',
    3: '3 أيام',
    4: '4 أيام',
    5: '5 أيام',
    7: 'أسبوع',
  };
  static const _prepDays = {
    0: 'في نفس اليوم',
    1: 'يوم واحد',
    2: 'يومان',
    3: '3 أيام',
    5: '5 أيام',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _freeOver.dispose();
    _pickupAddress.dispose();
    _samePrice.dispose();
    for (final c in _fees.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _plain(double? v) => v == null ? '' : v.toStringAsFixed(0);

  void _fill(StoreShippingSettings s) {
    _freeOver.text = _plain(s.freeOver);
    _pickupAddress.text = s.pickupAddress ?? '';
    for (final r in s.rates) {
      (_fees[r.governorate] ??= TextEditingController()).text = _plain(r.fee);
    }
    _settings = s;
  }

  Future<void> _load() async {
    setState(() => _loadError = null);
    try {
      final s = await _service.load();
      if (mounted) setState(() => _fill(s));
    } on ApiException catch (e) {
      if (mounted) setState(() => _loadError = e.message);
    } catch (_) {
      if (mounted) setState(() => _loadError = 'تعذّر تحميل إعدادات الشحن.');
    }
  }

  Future<void> _save() async {
    final s = _settings!;
    s.freeOver = double.tryParse(_freeOver.text.trim());
    s.pickupAddress = _pickupAddress.text.trim();
    for (final r in s.rates) {
      r.fee = double.tryParse(_fees[r.governorate]?.text.trim() ?? '');
    }
    setState(() {
      _saving = true;
      _saveError = null;
    });
    try {
      final saved = await _service.save(s);
      if (!mounted) return;
      setState(() => _fill(saved));
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم حفظ إعدادات الشحن.')));
    } on ApiException catch (e) {
      if (mounted) setState(() => _saveError = e.message);
    } catch (_) {
      if (mounted) setState(() => _saveError = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _applySamePrice() {
    final price = _samePrice.text.trim();
    if (price.isEmpty) return;
    setState(() {
      for (final r in _settings!.rates.where((r) => r.enabled)) {
        _fees[r.governorate]?.text = price;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final s = _settings;
    return Scaffold(
      appBar: AppBar(title: const AppText('إعدادات الشحن')),
      body: _loadError != null
          ? AppStateMessage(
              message: _loadError!, icon: Icons.error_outline, onRetry: _load)
          : s == null
              ? const LoadingIndicator()
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                  children: [
                    ..._statusCards(s),
                    _modeCard(s),
                    if (s.mode == 'self') _ratesCard(s),
                    _timesCard(s),
                    _pickupCard(s),
                    if (s.mode == 'self') _moneyCard(),
                    if (_saveError != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: AppText(_saveError!,
                            style: const TextStyle(color: AppColors.danger)),
                      ),
                    FilledButton.icon(
                      key: const ValueKey('shipping-save'),
                      onPressed: _saving ? null : _save,
                      icon: const Icon(Icons.save_outlined),
                      label: const AppText('حفظ إعدادات الشحن'),
                    ),
                  ],
                ),
    );
  }

  List<Widget> _statusCards(StoreShippingSettings s) {
    final st = s.status;
    return [
      if (s.mode == 'self')
        Card(
          color: st.active ? const Color(0xFFE6F4EA) : const Color(0xFFFFF4E0),
          child: ListTile(
            leading: Icon(
                st.active ? Icons.check_circle : Icons.pause_circle_filled,
                color: st.active ? AppColors.emerald : const Color(0xFFC9962C)),
            title: st.active
                ? const AppText(
                    'التوصيل الخاص يعمل الآن. طلبات المحافظات التي حددتها توصلها بنفسك، وباقي المحافظات تُشحن عبر شركة الشحن.',
                    style: TextStyle(fontSize: 13))
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (st.reason != null)
                        AppText(st.reason!,
                            style: const TextStyle(fontSize: 13)),
                      const AppText(
                          'حتى ذلك الحين تُشحن كل طلباتك عبر شركة الشحن.',
                          style: TextStyle(fontSize: 13)),
                    ],
                  ),
          ),
        ),
      if (st.debt > 0)
        Card(
          key: const ValueKey('shipping-debt'),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AppText(
                    'المبلغ الذي عليك للمنصة (عمولات طلبات حصّلت ثمنها بنفسك)',
                    style: TextStyle(fontSize: 12, color: AppColors.muted)),
                const SizedBox(height: 4),
                AppText('${_money.format(st.debt)} ل.س',
                    style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.danger)),
                if (st.limit > 0)
                  Row(children: [
                    const AppText('الحد الأعلى المسموح:',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(width: 4),
                    AppText('${_money.format(st.limit)} ل.س',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ]),
              ],
            ),
          ),
        ),
    ];
  }

  Widget _modeCard(StoreShippingSettings s) {
    Widget option(String value, IconData icon, String title, String hint) =>
        RadioListTile<String>(
          key: ValueKey('shipping-mode-$value'),
          value: value,
          secondary: Icon(icon, color: AppColors.emerald),
          title: AppText(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
          subtitle: AppText(hint, style: const TextStyle(fontSize: 12)),
        );

    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: AppText('من يوصل طلباتك؟',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
          RadioGroup<String>(
            groupValue: s.mode,
            onChanged: (v) => setState(() => s.mode = v ?? s.mode),
            child: Column(children: [
              option(
                  'platform',
                  Icons.local_shipping_outlined,
                  'شركة الشحن (كرم)',
                  'تسلّم الطرد لمركز الشحن، وهم يوصلونه لكل المحافظات.'),
              option('self', Icons.delivery_dining_outlined, 'أوصل بنفسي',
                  'بموظف توصيل عندك أو شركة تتعامل معها، وبأسعارك أنت.'),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _ratesCard(StoreShippingSettings s) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('المحافظات التي توصل إليها بنفسك',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            const AppText(
                'علّم المحافظة واكتب سعر التوصيل إليها. المحافظات التي لا تعلّمها تُشحن طلباتها عبر شركة الشحن.',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _samePrice,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                      isDense: true,
                      labelText: context.tr('نفس السعر للمحافظات المعلّمة'),
                      suffixText: context.tr('ل.س')),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                  onPressed: _applySamePrice, child: const AppText('تطبيق')),
            ]),
            const SizedBox(height: 8),
            for (final r in s.rates)
              Row(
                key: ValueKey('shipping-rate-${r.governorate}'),
                children: [
                  Checkbox(
                    value: r.enabled,
                    onChanged: (v) => setState(() => r.enabled = v ?? false),
                  ),
                  Expanded(child: Text(r.label)),
                  SizedBox(
                    width: 120,
                    child: TextField(
                      controller: _fees[r.governorate],
                      enabled: r.enabled,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: InputDecoration(
                          isDense: true, suffixText: context.tr('ل.س')),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  Widget _timesCard(StoreShippingSettings s) {
    DropdownButtonFormField<int> days(String key, String label, int value,
        Map<int, String> choices, ValueChanged<int> onChanged) {
      final options = {
        ...choices,
        if (!choices.containsKey(value)) value: '$value',
      };
      return DropdownButtonFormField<int>(
        key: ValueKey(key),
        initialValue: value,
        decoration: InputDecoration(labelText: context.tr(label)),
        items: [
          for (final e in options.entries)
            DropdownMenuItem(value: e.key, child: AppText(e.value)),
        ],
        onChanged: (v) => setState(() => onChanged(v ?? value)),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (s.mode == 'self') ...[
              TextField(
                controller: _freeOver,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText:
                      context.tr('شحن مجاني إذا اشترى الزبون منك بأكثر من'),
                  helperText:
                      context.tr('اتركه فارغاً إذا لا تريد شحناً مجانياً.'),
                  suffixText: context.tr('ل.س'),
                ),
              ),
              const SizedBox(height: 12),
              days(
                  'shipping-delivery-days',
                  'كم يوماً يستغرق التوصيل بعد التجهيز؟',
                  s.deliveryDays,
                  _deliveryDays,
                  (v) => s.deliveryDays = v),
              const SizedBox(height: 12),
            ],
            days(
                'shipping-prep-days',
                'خلال كم يوم تجهّز الطلب وتسلّمه للتوصيل؟',
                s.prepDays,
                _prepDays,
                (v) => s.prepDays = v),
            const SizedBox(height: 6),
            const AppText('يظهر للزبون قبل الشراء: «يصل خلال ... أيام».',
                style: TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
        ),
      ),
    );
  }

  Widget _pickupCard(StoreShippingSettings s) {
    return Card(
      child: Column(
        children: [
          SwitchListTile(
            key: const ValueKey('shipping-pickup'),
            value: s.allowPickup,
            onChanged: (v) => setState(() => s.allowPickup = v),
            title: const AppText('الاستلام من محلك',
                style: TextStyle(fontWeight: FontWeight.bold)),
            subtitle: const AppText(
                'أسمح للزبون أن يأتي ويستلم طلبه من محلي بدون أجرة شحن',
                style: TextStyle(fontSize: 12)),
          ),
          if (s.allowPickup)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: TextField(
                key: const ValueKey('shipping-pickup-address'),
                controller: _pickupAddress,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: context.tr('عنوان المحل'),
                  hintText: context
                      .tr('مثال: دمشق - الحمرا - بناء 12 - بجانب الصيدلية'),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _moneyCard() {
    const lines = [
      'أجرة التوصيل كلها لك.',
      'إذا دفع الزبون نقداً عند الاستلام، فالمال في يدك، ويبقى عليك عمولة المنصة فقط.',
      'العمولة تُخصم من رصيد محفظتك، وإن لم يكفِ تصبح ديناً يُخصم من مبيعاتك القادمة.',
      'إذا وصل الدين إلى الحد الأعلى يتوقف التوصيل الخاص حتى تسدّده.',
    ];
    return Card(
      color: const Color(0xFFFBF7F0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AppText('كيف يُحسب المال عندما توصل بنفسك؟',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            for (final line in lines)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('• '),
                    Expanded(
                        child: AppText(line,
                            style: const TextStyle(fontSize: 13))),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
