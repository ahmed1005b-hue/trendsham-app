import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../models/seller_coupon.dart';
import '../../services/api_exception.dart';
import '../../services/seller_coupon_service.dart';

/// إنشاء كوبون أو تعديله. بعد أن يجمعه عملاء: تمديد النهاية وزيادة العدد فقط.
/// يعود بـ Navigator.pop(رسالة الخادم) عند الحفظ.
class SellerCouponFormScreen extends StatefulWidget {
  const SellerCouponFormScreen({
    super.key,
    required this.service,
    required this.page,
    this.coupon,
  });

  final SellerCouponService service;
  final SellerCouponsPage page;
  final SellerCoupon? coupon;

  @override
  State<SellerCouponFormScreen> createState() => _SellerCouponFormScreenState();
}

class _SellerCouponFormScreenState extends State<SellerCouponFormScreen> {
  static const _types = {
    'percentage': 'نسبة مئوية',
    'fixed': 'مبلغ ثابت',
    'free_shipping': 'شحن مجاني',
    'gift': 'منتج هدية',
  };

  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _value;
  late final TextEditingController _maxDiscount;
  late final TextEditingController _minOrder;
  late final TextEditingController _totalLimit;
  late final TextEditingController _validDays;
  late String _type;
  late String _scope;
  late String _audience;
  late bool _autoFollowers;
  late int _perCustomer;
  DateTime? _startsAt;
  late DateTime _endsAt;
  int? _buyProductId;
  int? _giftProductId;
  late Set<int> _productIds;
  Map<String, String> _errors = {};
  bool _saving = false;

  SellerCoupon? get _coupon => widget.coupon;
  bool get _locked => _coupon?.isLocked ?? false;

  String _plain(num? v) =>
      v == null ? '' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');

  @override
  void initState() {
    super.initState();
    final c = _coupon;
    _title = TextEditingController(text: c?.title ?? '');
    _value = TextEditingController(text: _plain(c?.value));
    _maxDiscount = TextEditingController(text: _plain(c?.maxDiscount));
    _minOrder = TextEditingController(
        text:
            c == null || c.minOrderAmount == 0 ? '' : _plain(c.minOrderAmount));
    _totalLimit = TextEditingController(text: '${c?.totalLimit ?? 100}');
    _validDays = TextEditingController(text: c?.validDays?.toString() ?? '');
    _type = c?.type ?? 'percentage';
    _scope = c?.scope ?? 'all';
    _audience = c?.audience ?? 'collectable';
    _autoFollowers = c?.autoFollowers ?? false;
    _perCustomer = (c?.perCustomerLimit ?? 1).clamp(1, 5);
    _startsAt = c?.startsAt;
    _endsAt = c?.endsAt ?? DateTime.now().add(const Duration(days: 14));
    _buyProductId = c?.buyProductId;
    _giftProductId = c?.giftProductId;
    _productIds = {...?c?.productIds};
  }

  @override
  void dispose() {
    for (final c in [
      _title,
      _value,
      _maxDiscount,
      _minOrder,
      _totalLimit,
      _validDays
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String _ymd(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> _body() {
    if (_locked) {
      return {
        'ends_at': _ymd(_endsAt),
        'total_limit': int.tryParse(_totalLimit.text.trim()),
      };
    }
    return {
      'title': _title.text.trim(),
      'type': _type,
      if (_type == 'percentage' || _type == 'fixed')
        'value': num.tryParse(_value.text.trim()),
      if (_type == 'percentage')
        'max_discount': num.tryParse(_maxDiscount.text.trim()),
      'min_order_amount': num.tryParse(_minOrder.text.trim()) ?? 0,
      if (_type == 'gift') 'buy_product_id': _buyProductId,
      if (_type == 'gift') 'gift_product_id': _giftProductId,
      'scope': _scope,
      if (_scope == 'products') 'product_ids': _productIds.toList(),
      'audience': _audience,
      'auto_followers': _audience == 'collectable' && _autoFollowers,
      if (_startsAt != null) 'starts_at': _ymd(_startsAt!),
      'ends_at': _ymd(_endsAt),
      if (_validDays.text.trim().isNotEmpty)
        'valid_days': int.tryParse(_validDays.text.trim()),
      'total_limit': int.tryParse(_totalLimit.text.trim()),
      'per_customer_limit': _perCustomer,
    };
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_locked && _scope == 'products' && _productIds.isEmpty) {
      setState(() => _errors = {
            'product_ids': context.tr('اختر منتجاً واحداً على الأقل من متجرك.')
          });
      return;
    }
    setState(() {
      _saving = true;
      _errors = {};
    });
    try {
      final message = _coupon == null
          ? await widget.service.create(_body())
          : await widget.service.update(_coupon!.id, _body());
      if (mounted) Navigator.of(context).pop(message);
    } on ApiException catch (e) {
      if (!mounted) return;
      final errors = <String, String>{};
      e.errors?.forEach((key, value) {
        final first = value is List && value.isNotEmpty ? value.first : value;
        errors[key.split('.').first] = '$first';
      });
      setState(() {
        _saving = false;
        _errors = errors;
      });
      if (errors.isEmpty) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _pickDate({required bool start}) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: start ? (_startsAt ?? now) : _endsAt,
      firstDate: start ? now : (_locked ? _endsAt : now),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() => start ? _startsAt = picked : _endsAt = picked);
  }

  InputDecoration _decoration(String label, {String? field, String? hint}) =>
      InputDecoration(
        labelText: context.tr(label),
        helperText: hint == null ? null : context.tr(hint),
        helperMaxLines: 3,
        errorText: field == null ? null : _errors[field],
        border: const OutlineInputBorder(),
      );

  String? _required(String? v) =>
      (v ?? '').trim().isEmpty ? context.tr('هذا الحقل مطلوب.') : null;

  Widget _gap() => const SizedBox(height: 14);

  @override
  Widget build(BuildContext context) {
    final page = widget.page;
    final giftable = page.products.where((p) => !p.hasVariants).toList();
    return Scaffold(
      appBar: AppBar(
        title: AppText(_coupon == null ? 'كوبون جديد' : 'تعديل الكوبون'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_locked)
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const AppText(
                  'جمع العملاء هذا الكوبون، لذلك يمكنك فقط تمديد تاريخ الانتهاء وزيادة العدد.',
                ),
              ),
            if (!_locked) ...[
              TextFormField(
                key: const ValueKey('coupon-title'),
                controller: _title,
                maxLength: 120,
                decoration: _decoration('اسم الكوبون', field: 'title'),
                validator: _required,
              ),
              _gap(),
              AppText('نوع الخصم',
                  style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final entry in _types.entries)
                    ChoiceChip(
                      key: ValueKey('type-${entry.key}'),
                      label: AppText(entry.value),
                      selected: _type == entry.key,
                      onSelected: (_) => setState(() => _type = entry.key),
                    ),
                ],
              ),
              _gap(),
              if (_type == 'percentage' || _type == 'fixed') ...[
                TextFormField(
                  key: const ValueKey('coupon-value'),
                  controller: _value,
                  keyboardType: TextInputType.number,
                  decoration: _decoration(
                    _type == 'percentage' ? 'نسبة الخصم %' : 'مبلغ الخصم (ل.س)',
                    field: 'value',
                    hint: _type == 'percentage'
                        ? context
                            .tr('حتى :max%. فوق :review% ينتظر موافقة الإدارة.')
                            .replaceAll(':max', '${page.maxPercent}')
                            .replaceAll(':review', '${page.reviewAbovePercent}')
                        : null,
                  ),
                  validator: (v) {
                    final n = num.tryParse((v ?? '').trim());
                    if (n == null || n <= 0) {
                      return context.tr('أدخل قيمة الخصم.');
                    }
                    if (_type == 'percentage' && n > page.maxPercent) {
                      return context
                          .tr('أعلى نسبة مسموحة :max%.')
                          .replaceAll(':max', '${page.maxPercent}');
                    }
                    return null;
                  },
                ),
                _gap(),
              ],
              if (_type == 'percentage') ...[
                TextFormField(
                  key: const ValueKey('coupon-max'),
                  controller: _maxDiscount,
                  keyboardType: TextInputType.number,
                  decoration: _decoration('أعلى مبلغ للخصم (ل.س)',
                      field: 'max_discount'),
                  validator: _required,
                ),
                _gap(),
              ],
              if (_type == 'gift') ...[
                DropdownButtonFormField<int>(
                  key: const ValueKey('coupon-buy'),
                  initialValue: _buyProductId,
                  isExpanded: true,
                  decoration: _decoration('المنتج الذي يشتريه العميل',
                      field: 'buy_product_id'),
                  items: [
                    for (final p in page.products)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _buyProductId = v),
                  validator: (v) => v == null
                      ? context.tr('اختر المنتج الذي يشتريه العميل.')
                      : null,
                ),
                _gap(),
                DropdownButtonFormField<int>(
                  key: const ValueKey('coupon-gift'),
                  initialValue: _giftProductId,
                  isExpanded: true,
                  decoration: _decoration('منتج الهدية',
                      field: 'gift_product_id',
                      hint: 'منتج بلا ألوان أو مقاسات.'),
                  items: [
                    for (final p in giftable)
                      DropdownMenuItem(
                        value: p.id,
                        child: Text(p.name, overflow: TextOverflow.ellipsis),
                      ),
                  ],
                  onChanged: (v) => setState(() => _giftProductId = v),
                  validator: (v) =>
                      v == null ? context.tr('اختر منتج الهدية.') : null,
                ),
                _gap(),
              ],
              TextFormField(
                controller: _minOrder,
                keyboardType: TextInputType.number,
                decoration: _decoration('أقل مبلغ للطلب (ل.س، اختياري)',
                    field: 'min_order_amount'),
              ),
              _gap(),
              AppText('يُطبَّق على',
                  style: Theme.of(context).textTheme.titleSmall),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: AppText('كل منتجاتي')),
                  ButtonSegment(
                      value: 'products', label: AppText('منتجات محددة')),
                ],
                selected: {_scope},
                onSelectionChanged: (s) => setState(() => _scope = s.first),
              ),
              if (_scope == 'products') ...[
                const SizedBox(height: 6),
                if (_errors['product_ids'] != null)
                  Text(_errors['product_ids']!,
                      style: const TextStyle(color: Colors.red, fontSize: 12)),
                for (final p in page.products)
                  CheckboxListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    value: _productIds.contains(p.id),
                    title: Text(p.name),
                    onChanged: (on) => setState(() => on == true
                        ? _productIds.add(p.id)
                        : _productIds.remove(p.id)),
                  ),
              ],
              _gap(),
              AppText('من يحصل عليه',
                  style: Theme.of(context).textTheme.titleSmall),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'collectable', label: AppText('يجمعه أي عميل')),
                  ButtonSegment(
                      value: 'followers', label: AppText('متابعو متجري')),
                ],
                selected: {_audience},
                onSelectionChanged: (s) => setState(() => _audience = s.first),
              ),
              if (_audience == 'collectable')
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _autoFollowers,
                  onChanged: (v) => setState(() => _autoFollowers = v),
                  title: AppText(context
                      .tr('أرسله أيضاً لمتابعي متجري (:n)')
                      .replaceAll(':n', '${page.followersCount}')),
                ),
              _gap(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_arrow_outlined),
                title: const AppText('يبدأ'),
                subtitle: _startsAt == null
                    ? const AppText('من الآن')
                    : Text(_ymd(_startsAt!)),
                trailing: const Icon(Icons.edit_calendar_outlined),
                onTap: () => _pickDate(start: true),
              ),
            ],
            ListTile(
              key: const ValueKey('coupon-ends'),
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.event_outlined),
              title: const AppText('ينتهي'),
              subtitle: Text(_ymd(_endsAt)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: () => _pickDate(start: false),
            ),
            if (_errors['ends_at'] != null)
              Text(_errors['ends_at']!,
                  style: const TextStyle(color: Colors.red, fontSize: 12)),
            _gap(),
            TextFormField(
              key: const ValueKey('coupon-total'),
              controller: _totalLimit,
              keyboardType: TextInputType.number,
              decoration: _decoration('عدد الكوبونات', field: 'total_limit'),
              validator: (v) {
                final n = int.tryParse((v ?? '').trim());
                if (n == null || n < 1) {
                  return context.tr('حدد عدد الكوبونات حتى تعرف أقصى تكلفة.');
                }
                if (_locked && n < (_coupon?.totalLimit ?? 0)) {
                  return context
                      .tr('بعد أن جمعه العملاء يمكنك زيادة العدد فقط.');
                }
                return null;
              },
            ),
            if (!_locked) ...[
              _gap(),
              DropdownButtonFormField<int>(
                initialValue: _perCustomer,
                decoration: _decoration('مرات الاستخدام لكل عميل',
                    field: 'per_customer_limit'),
                items: [
                  for (var i = 1; i <= 5; i++)
                    DropdownMenuItem(value: i, child: Text('$i')),
                ],
                onChanged: (v) => setState(() => _perCustomer = v ?? 1),
              ),
              _gap(),
              TextFormField(
                controller: _validDays,
                keyboardType: TextInputType.number,
                decoration: _decoration('صلاحيته بعد الجمع (أيام، اختياري)',
                    field: 'valid_days'),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              key: const ValueKey('coupon-save'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.brandGreen,
                minimumSize: const Size.fromHeight(50),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    )
                  : AppText(_coupon == null ? 'حفظ الكوبون' : 'حفظ التعديلات'),
            ),
          ],
        ),
      ),
    );
  }
}
