import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/payment_method_service.dart';
import '../../l10n/app_localizations.dart';

const _typeLabels = {
  'bank_account': 'حساب بنكي (IBAN)',
  'bank_card': 'بطاقة بنكية',
  'electronic_wallet': 'محفظة إلكترونية',
};

const _typeIcons = {
  'bank_account': Icons.account_balance_rounded,
  'bank_card': Icons.credit_card_rounded,
  'electronic_wallet': Icons.phone_android_rounded,
};

/// طرق استلام أرباح البائع. الرقم الكامل لا يعود من السيرفر أبداً — آخر 4 أرقام فقط.
class SellerPaymentMethodsScreen extends StatefulWidget {
  const SellerPaymentMethodsScreen({super.key});

  @override
  State<SellerPaymentMethodsScreen> createState() =>
      _SellerPaymentMethodsScreenState();
}

class _SellerPaymentMethodsScreenState
    extends State<SellerPaymentMethodsScreen> {
  final PaymentMethodService _service = PaymentMethodService();
  List<Map<String, dynamic>> _methods = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final methods = await _service.getPaymentMethods();
      if (!mounted) return;
      setState(() {
        _methods = methods;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل طرق الاستلام.';
        _loading = false;
      });
    }
  }

  Future<void> _run(Future<void> Function() action, String failMsg) async {
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast(failMsg);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(msg)));
  }

  Future<void> _confirmDelete(Map<String, dynamic> m) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف طريقة الاستلام'),
        content: AppText('حذف ${m['provider']} ${m['masked_number']}؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('إلغاء')),
          FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف')),
        ],
      ),
    );
    if (ok == true) {
      await _run(() => _service.deletePaymentMethod(m['id'] as int),
          'تعذّر حذف طريقة الاستلام.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('طرق استلام الأرباح')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const AppText('إضافة'),
        onPressed: () async {
          final added = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    SellerAddPaymentMethodScreen(isFirst: _methods.isEmpty)),
          );
          if (added == true) _load();
        },
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return ListView(children: [
        const SizedBox(height: 120),
        const Icon(Icons.error_outline, size: 56, color: AppColors.danger),
        const SizedBox(height: 12),
        Center(child: AppText(_error!)),
        Center(
            child: TextButton(
                onPressed: _load, child: const AppText('إعادة المحاولة'))),
      ]);
    }
    if (_methods.isEmpty) {
      return ListView(children: const [
        SizedBox(height: 120),
        Icon(Icons.account_balance_outlined, size: 64, color: AppColors.muted),
        SizedBox(height: 12),
        Center(child: AppText('لا توجد طرق استلام بعد.')),
        SizedBox(height: 4),
        Center(
          child: AppText('أضف حسابك البنكي أو محفظتك لتتمكن من سحب أرباحك.',
              style: TextStyle(color: AppColors.muted, fontSize: 13)),
        ),
      ]);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 90),
      itemCount: _methods.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, i) {
        final m = _methods[i];
        final type = (m['type'] ?? '').toString();
        final isDefault = m['is_default'] == true;
        final verified = m['is_verified'] == true;
        return Container(
          decoration: BoxDecoration(
            color: context.cardSurface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
                color: isDefault ? AppColors.emerald : context.cardBorder,
                width: isDefault ? 1.5 : 1),
          ),
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: context.softTint(AppColors.emerald),
                child: Icon(_typeIcons[type] ?? Icons.account_balance_wallet,
                    color: AppColors.emerald),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AppText((m['provider'] ?? '').toString(),
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    AppText(_typeLabels[type] ?? type,
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 4),
                    AppText((m['masked_number'] ?? '').toString(),
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(
                            letterSpacing: 1.5, fontWeight: FontWeight.w600)),
                    AppText((m['account_holder_name'] ?? '').toString(),
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(height: 6),
                    Wrap(spacing: 6, runSpacing: 4, children: [
                      if (isDefault) _chip('افتراضية', AppColors.emerald),
                      _chip(
                          verified ? 'موثّقة' : 'بانتظار التوثيق',
                          verified
                              ? const Color(0xFF1A56DB)
                              : const Color(0xFFB25E00)),
                    ]),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'default') {
                    _run(() => _service.setDefaultPaymentMethod(m['id'] as int),
                        'تعذّر تعيين الطريقة الافتراضية.');
                  } else if (v == 'delete') {
                    _confirmDelete(m);
                  }
                },
                itemBuilder: (_) => [
                  if (!isDefault)
                    const PopupMenuItem(
                        value: 'default', child: AppText('اجعلها افتراضية')),
                  const PopupMenuItem(value: 'delete', child: AppText('حذف')),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: context.softTint(color),
          borderRadius: BorderRadius.circular(20),
        ),
        child: AppText(text,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.bold)),
      );
}

class SellerAddPaymentMethodScreen extends StatefulWidget {
  const SellerAddPaymentMethodScreen({super.key, this.isFirst = false});
  final bool isFirst;

  @override
  State<SellerAddPaymentMethodScreen> createState() =>
      _SellerAddPaymentMethodScreenState();
}

class _SellerAddPaymentMethodScreenState
    extends State<SellerAddPaymentMethodScreen> {
  final _service = PaymentMethodService();
  final _formKey = GlobalKey<FormState>();
  final _provider = TextEditingController();
  final _number = TextEditingController();
  final _holder = TextEditingController();
  String _type = 'bank_account';
  late bool _isDefault = widget.isFirst;
  Map<String, List<String>> _providers = {};
  bool _saving = false;
  String? _numberError;

  @override
  void initState() {
    super.initState();
    _service.payoutOptions().then((o) {
      final raw = o['providers'];
      if (!mounted || raw is! Map) return;
      setState(() => _providers = raw.map((k, v) => MapEntry(
          k.toString(), (v as List).map((e) => e.toString()).toList())));
    }).catchError((_) {});
  }

  @override
  void dispose() {
    _provider.dispose();
    _number.dispose();
    _holder.dispose();
    super.dispose();
  }

  (String providerLabel, String numberLabel, String help) get _meta =>
      switch (_type) {
        'bank_card' => (
            'نوع البطاقة',
            'رقم البطاقة',
            '16 رقماً كما على البطاقة. لا نطلب CVV أو تاريخ الانتهاء.'
          ),
        'electronic_wallet' => (
            'المحفظة',
            'رقم المحفظة / الهاتف',
            'رقم الهاتف المرتبط بالمحفظة، مثل 0933123456.'
          ),
        _ => (
            'البنك',
            'رقم IBAN أو رقم الحساب',
            'مثال: TR33 0006 1005 1978 6457 8413 26 — انسخه من تطبيق البنك.'
          ),
      };

  Future<void> _save() async {
    setState(() => _numberError = null);
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _service.addPaymentMethod(
        type: _type,
        provider: _provider.text.trim(),
        accountNumber: _number.text.trim(),
        accountHolderName: _holder.text.trim(),
        isDefault: _isDefault,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تمت إضافة طريقة الاستلام.')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      final fieldError = e.errors?['account_number'];
      setState(() => _numberError = fieldError is List && fieldError.isNotEmpty
          ? fieldError.first.toString()
          : null);
      if (_numberError == null && mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final (providerLabel, numberLabel, help) = _meta;
    final options = _providers[_type] ?? const <String>[];

    return Scaffold(
      appBar: AppBar(title: const AppText('إضافة طريقة استلام')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: [
                for (final e in _typeLabels.entries)
                  ButtonSegment(
                      value: e.key,
                      icon: Icon(_typeIcons[e.key], size: 18),
                      label: AppText(e.value.split(' ').first,
                          style: const TextStyle(fontSize: 12))),
              ],
              selected: {_type},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() {
                _type = s.first;
                _provider.clear();
                _numberError = null;
              }),
            ),
            const SizedBox(height: 6),
            AppText(_typeLabels[_type]!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 16),
            Autocomplete<String>(
              key: ValueKey(_type),
              optionsBuilder: (v) => options.where((o) =>
                  v.text.isEmpty ||
                  o.toLowerCase().contains(v.text.toLowerCase())),
              onSelected: (v) => _provider.text = v,
              fieldViewBuilder: (context, controller, focus, onSubmit) {
                return TextFormField(
                  controller: controller,
                  focusNode: focus,
                  onChanged: (v) => _provider.text = v,
                  decoration: InputDecoration(
                      labelText: providerLabel,
                      suffixIcon: const Icon(Icons.arrow_drop_down)),
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? context.tr('مطلوب') : null,
                );
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _number,
              textDirection: TextDirection.ltr,
              keyboardType: _type == 'bank_account'
                  ? TextInputType.text
                  : TextInputType.number,
              textCapitalization: TextCapitalization.characters,
              decoration: InputDecoration(
                labelText: numberLabel,
                helperText: help,
                helperMaxLines: 2,
                errorText: _numberError,
                errorMaxLines: 2,
              ),
              validator: (v) => (v == null || v.trim().length < 6)
                  ? context.tr('أدخل رقماً صحيحاً')
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _holder,
              decoration: InputDecoration(
                  labelText: context.tr('اسم صاحب الحساب (كما في البنك)')),
              validator: (v) =>
                  (v == null || v.trim().length < 3) ? context.tr('مطلوب') : null,
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _isDefault,
              onChanged: (v) => setState(() => _isDefault = v),
              title: const AppText('الطريقة الافتراضية للسحب'),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: _saving
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const AppText('حفظ'),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                SizedBox(width: 6),
                Expanded(
                  child: AppText(
                    'يُحفظ الرقم مشفّراً، ولا يظهر كاملاً إلا للإدارة عند تنفيذ الحوالة.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
