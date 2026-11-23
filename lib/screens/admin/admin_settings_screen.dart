import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// حقل رقمي في إعدادات المنصة.
class _Field {
  const _Field(this.key, this.label,
      {this.hint, this.suffix, this.money = false, this.integer = true});

  final String key;
  final String label;
  final String? hint;
  final String? suffix;

  /// مبلغ بالليرة (يقبل كسوراً)
  final bool money;
  final bool integer;
}

/// قسم من الإعدادات (نفس أقسام صفحة الإعدادات في الموقع).
class _Section {
  const _Section(this.title, this.fields, {this.intro});

  final String title;
  final String? intro;
  final List<_Field> fields;
}

const _sections = [
  _Section(
    'نسبة العمولة العامة',
    [_Field('commission_rate', 'النسبة %', suffix: '%')],
    intro:
        'تُطبَّق على كل الطلبات المسلَّمة، ما لم يكن للبائع نسبة خاصة متفاوض عليها.',
  ),
  _Section(
    'رسم نشر الستوري',
    [_Field('story_fee', 'المبلغ', money: true, integer: false)],
    intro:
        'المبلغ الذي يُخصم من محفظة البائع مقابل نشر ستوري واحدة لمدة 24 ساعة.',
  ),
  _Section('أجور الشحن (شركة كرم)', [
    _Field('shipping_parcel_fee', 'أجرة الطرد (أقل من 10 كغ)',
        money: true, integer: false),
    _Field('shipping_heavy_parcel_fee', 'أجرة الطرد الثقيل (10 كغ أو أكثر)',
        money: true, integer: false),
    _Field('shipping_home_extra', 'مبلغ إضافي للتوصيل إلى البيت',
        hint:
            'لكل طرد. اكتب 0 إذا كان التوصيل للبيت بنفس سعر الاستلام من المركز.',
        money: true,
        integer: false),
    _Field('seller_debt_limit', 'الحد الأعلى لدين البائع',
        hint:
            'متاجر توصل بنفسها وتحصّل المال نقداً: تصبح عمولتها ديناً عليها. إذا بلغ الدين هذا الحد يتوقف توصيلها الخاص حتى تسدّد. اكتب 0 لإلغاء الحد.',
        money: true,
        integer: false),
    _Field('self_delivery_min_orders',
        'عدد الطلبات الناجحة قبل السماح للمتجر بالتوصيل بنفسه',
        hint:
            'طرود سلّمها المتجر بنجاح عبر شركة الشحن، وللمتاجر الموثّقة فقط. اكتب 0 للسماح فوراً.'),
  ]),
  _Section(
    'مهل المرتجعات',
    [
      _Field('returns_window_days', 'مدة الإرجاع بعد التسليم', suffix: 'أيام'),
      _Field(
          'returns_seller_response_days', 'مهلة رد البائع قبل الإحالة للإدارة',
          suffix: 'أيام'),
      _Field('returns_dispute_days', 'مهلة فتح النزاع بعد رفض البائع',
          suffix: 'أيام'),
      _Field('returns_ship_back_days', 'مهلة إعادة المنتج بعد الموافقة',
          suffix: 'أيام'),
    ],
    intro:
        'عدد الأيام لكل مرحلة من مسار الإرجاع. التغيير يطبّق على المهل اللي تبدأ بعد الحفظ.',
  ),
];

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminService? service;

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  late final AdminService _service = widget.service ?? AdminService();
  final Map<String, TextEditingController> _controllers = {
    for (final section in _sections)
      for (final f in section.fields) f.key: TextEditingController(),
  };

  /// الحقول التي أرسلها الخادم (خادم أقدم قد لا يعرف بعضها)
  final Set<String> _known = {};

  bool _isLoading = true;
  bool _isSaving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  String _plain(dynamic v) {
    final n = v is num ? v : num.tryParse('$v');
    if (n == null) return '';
    return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _service.settings();
      _known
        ..clear()
        ..addAll(data.keys.where(_controllers.containsKey));
      for (final key in _known) {
        _controllers[key]!.text = _plain(data[key]);
      }
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر تحميل الإعدادات.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _save() async {
    final values = <String, num>{};
    for (final section in _sections) {
      for (final f in section.fields.where((f) => _known.contains(f.key))) {
        final text = _controllers[f.key]!.text.trim();
        final value = f.integer ? int.tryParse(text) : num.tryParse(text);
        if (value == null) {
          setState(() => _error = 'أدخل أرقام صحيحة.');
          return;
        }
        values[f.key] = value;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await _service.updateSettings(values);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: AppText('تم حفظ الإعدادات.')));
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } catch (_) {
      setState(() => _error = 'تعذّر حفظ الإعدادات.');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('إعدادات المنصة')),
      body: _isLoading ? const LoadingIndicator() : _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
                color: context.softTint(Colors.red),
                borderRadius: BorderRadius.circular(8)),
            child: AppText(_error!,
                style: const TextStyle(color: AppColors.danger)),
          ),
        for (final section in _sections)
          if (section.fields.any((f) => _known.contains(f.key)))
            Card(
              margin: const EdgeInsets.only(bottom: 16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText(section.title,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    if (section.intro != null) ...[
                      const SizedBox(height: 4),
                      AppText(section.intro!,
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                    for (final f in section.fields)
                      if (_known.contains(f.key))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: TextField(
                            key: ValueKey('setting-${f.key}'),
                            controller: _controllers[f.key],
                            keyboardType: TextInputType.numberWithOptions(
                                decimal: !f.integer),
                            decoration: InputDecoration(
                              labelText: context.tr(f.label),
                              helperText:
                                  f.hint == null ? null : context.tr(f.hint!),
                              helperMaxLines: 4,
                              suffixText: f.money
                                  ? context.tr('ل.س')
                                  : (f.suffix == null
                                      ? null
                                      : context.tr(f.suffix!)),
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ),
        const SizedBox(height: 8),
        ElevatedButton(
          key: const ValueKey('settings-save'),
          onPressed: _isSaving ? null : _save,
          child: _isSaving
              ? const SizedBox(
                  height: 20,
                  width: 20,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white))
              : const AppText('حفظ الإعدادات'),
        ),
      ],
    );
  }
}
