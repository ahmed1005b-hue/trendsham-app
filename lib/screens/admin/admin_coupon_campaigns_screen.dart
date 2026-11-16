import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_client.dart';
import '../../services/api_exception.dart';
import '../../l10n/app_localizations.dart';

/// كوبونات المحفظة (المنصة تتحمّل خصمها). تصل لمحافظ العملاء مباشرة دون رموز.
class AdminCouponCampaignsScreen extends StatefulWidget {
  const AdminCouponCampaignsScreen({super.key});

  @override
  State<AdminCouponCampaignsScreen> createState() =>
      _AdminCouponCampaignsScreenState();
}

class _AdminCouponCampaignsScreenState
    extends State<AdminCouponCampaignsScreen> {
  final _api = ApiClient();
  List<Map<String, dynamic>>? _items;
  Map<String, dynamic> _sizes = const {};
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _api.get('/admin/coupon-campaigns');
      if (!mounted) return;
      setState(() {
        _items = (data['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _sizes = Map<String, dynamic>.from(data['audience_sizes'] ?? const {});
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الكوبونات.');
    }
  }

  Future<void> _toggle(Map<String, dynamic> c) async {
    try {
      await _api.post('/admin/coupon-campaigns/${c['id']}/toggle');
      _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(m)));
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => _CreateCampaignScreen(sizes: _sizes)));
    if (created == true) {
      _toast('تم إنشاء الكوبون.');
      _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('كوبونات المحفظة')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const AppText('كوبون جديد'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: _error != null
            ? ListView(children: [
                Padding(
                    padding: const EdgeInsets.all(32),
                    child: AppText(_error!, textAlign: TextAlign.center))
              ])
            : _items == null
                ? const Center(child: CircularProgressIndicator())
                : _items!.isEmpty
                    ? ListView(children: const [
                        Padding(
                            padding: EdgeInsets.all(48),
                            child: AppText('لا توجد كوبونات بعد.',
                                textAlign: TextAlign.center))
                      ])
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
                        itemCount: _items!.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (_, i) {
                          final c = _items![i];
                          final active = c['status'] == 'active';
                          return Card(
                            child: ListTile(
                              title: AppText('${c['title']}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              // كل سطر يُترجم وحده: الأجزاء الاختيارية المتجاورة لا تُطابَق كجملة واحدة
                              subtitle: AppText([
                                '${c['value_label']} · ${c['audience_label']}',
                                context.tr(
                                        'وصل لـ ${c['issued_count']} · استُخدم ${c['redeemed_count']}') +
                                    (c['total_limit'] != null
                                        ? ' / ${c['total_limit']}'
                                        : ''),
                                if (c['funder'] == 'seller')
                                  context
                                      .tr('من متجر ${c['store_name'] ?? ''}'),
                              ].join('\n')),
                              isThreeLine: true,
                              trailing: TextButton(
                                onPressed: () => _toggle(c),
                                style: TextButton.styleFrom(
                                    foregroundColor: active
                                        ? Colors.orange.shade800
                                        : AppColors.emerald),
                                child: AppText(active ? 'إيقاف' : 'تفعيل'),
                              ),
                            ),
                          );
                        },
                      ),
      ),
    );
  }
}

class _CreateCampaignScreen extends StatefulWidget {
  final Map<String, dynamic> sizes;

  const _CreateCampaignScreen({required this.sizes});

  @override
  State<_CreateCampaignScreen> createState() => _CreateCampaignScreenState();
}

class _CreateCampaignScreenState extends State<_CreateCampaignScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _value = TextEditingController();
  final _max = TextEditingController();
  final _min = TextEditingController(text: '0');
  final _contact = TextEditingController();
  final _days = TextEditingController();
  final _perCustomer = TextEditingController(text: '1');
  final _total = TextEditingController();
  String _type = 'percentage';
  String _audience = 'all_customers';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [
      _title,
      _value,
      _max,
      _min,
      _contact,
      _days,
      _perCustomer,
      _total
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    if (_audience == 'all_customers') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const AppText('تأكيد'),
          content: AppText(
              'سيظهر الكوبون في محفظة ${widget.sizes['all_customers'] ?? 'كل'} عميل. متأكد؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('تراجع')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('نعم')),
          ],
        ),
      );
      if (ok != true) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    String? t(TextEditingController c) =>
        c.text.trim().isEmpty ? null : c.text.trim();
    try {
      await ApiClient().post('/admin/coupon-campaigns', body: {
        'title': _title.text.trim(),
        'type': _type,
        if (_type != 'free_shipping') 'value': t(_value),
        if (_type == 'percentage' && t(_max) != null) 'max_discount': t(_max),
        'min_order_amount': t(_min) ?? '0',
        'scope': 'all',
        'audience': _audience,
        if (_audience == 'specific') 'customer_contact': t(_contact),
        if (t(_days) != null) 'valid_days': t(_days),
        'per_customer_limit': t(_perCustomer) ?? '1',
        if (t(_total) != null) 'total_limit': t(_total),
      });
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _num(TextEditingController c, String label,
          {bool required = false, String? hint}) =>
      TextFormField(
        controller: c,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(
            labelText: label,
            hintText: hint,
            border: const OutlineInputBorder()),
        validator: required
            ? (v) =>
                (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null
            : null,
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('كوبون جديد')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const AppText(
                'كوبون المنصة: المنصة تتحمّل الخصم ويأخذ البائع أرباحه كاملة.',
                style: TextStyle(color: AppColors.muted, fontSize: 13)),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              maxLength: 120,
              decoration: InputDecoration(
                  labelText: context.tr('اسم الكوبون (يراه العميل)'),
                  border: const OutlineInputBorder()),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null,
            ),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'percentage', label: AppText('نسبة')),
                ButtonSegment(value: 'fixed', label: AppText('مبلغ')),
                ButtonSegment(
                    value: 'free_shipping', label: AppText('شحن مجاني')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 12),
            if (_type != 'free_shipping') ...[
              _num(_value, _type == 'percentage' ? 'النسبة %' : 'المبلغ (ل.س)',
                  required: true),
              const SizedBox(height: 12),
            ],
            if (_type == 'percentage') ...[
              _num(_max, 'الحد الأعلى للخصم (ل.س)', hint: 'اختياري'),
              const SizedBox(height: 12),
            ],
            _num(_min, 'الحد الأدنى للسلة (ل.س)'),
            const SizedBox(height: 16),
            const AppText('لمن يصل؟',
                style: TextStyle(fontWeight: FontWeight.bold)),
            RadioGroup<String>(
              groupValue: _audience,
              onChanged: (v) => setState(() => _audience = v ?? _audience),
              child: Column(children: [
                RadioListTile(
                    value: 'new_customers',
                    title: AppText(
                        'العملاء الجدد (${widget.sizes['new_customers'] ?? 0} حالياً)')),
                RadioListTile(
                    value: 'all_customers',
                    title: AppText(
                        'كل العملاء (${widget.sizes['all_customers'] ?? 0})')),
                const RadioListTile(
                    value: 'specific', title: AppText('عميل معيّن')),
              ]),
            ),
            if (_audience == 'specific')
              TextFormField(
                controller: _contact,
                decoration: InputDecoration(
                    labelText: context.tr('هاتف العميل أو بريده'),
                    border: const OutlineInputBorder()),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? context.tr('مطلوب')
                    : null,
              ),
            const SizedBox(height: 16),
            const AppText('الحدود',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _num(_days, 'صالح لكل عميل (أيام)', hint: 'اختياري'),
            const SizedBox(height: 12),
            _num(_perCustomer, 'مرات الاستخدام لكل عميل', required: true),
            const SizedBox(height: 12),
            _num(_total, 'العدد الإجمالي', hint: 'بلا حد'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              AppText(_error!, style: const TextStyle(color: AppColors.danger)),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const AppText('إنشاء الكوبون'),
            ),
          ],
        ),
      ),
    );
  }
}
