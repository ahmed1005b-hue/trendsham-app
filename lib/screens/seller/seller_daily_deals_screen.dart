import 'package:flutter/material.dart';
import '../../config/theme.dart';
import '../../services/seller_service.dart';
import '../../services/api_exception.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/app_state_message.dart';

class SellerDailyDealsScreen extends StatefulWidget {
  const SellerDailyDealsScreen({super.key});

  @override
  State<SellerDailyDealsScreen> createState() => _SellerDailyDealsScreenState();
}

class _SellerDailyDealsScreenState extends State<SellerDailyDealsScreen> {
  final SellerService _service = SellerService();
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final data = await _service.dailyDeals();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'تعذّر تحميل العروض اليومية.';
        _loading = false;
      });
    }
  }

  Future<void> _openForm({Map<String, dynamic>? deal}) async {
    final products =
        (_data?['eligible_products'] as List?)?.whereType<Map>().toList() ?? [];
    if (products.isEmpty && deal == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: AppText(
            'لا توجد منتجات مؤهلة. يجب أن يكون منتجك مفعلاً ومعتمداً من الإدارة.',
          ),
        ),
      );
      return;
    }
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _DealFormSheet(
        products: products
            .map(
              (p) => {
                'id': (p['id'] as num).toInt(),
                'name': p['name'] as String? ?? '',
                'price': (p['price'] as num?)?.toDouble() ?? 0,
              },
            )
            .toList(),
        deal: deal,
      ),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(Map<String, dynamic> deal) async {
    try {
      await _service.toggleDailyDeal((deal['id'] as num).toInt());
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _delete(Map<String, dynamic> deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف العرض'),
        content: const AppText('هل تريد حذف هذا العرض اليومي؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('إلغاء'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('حذف'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _service.deleteDailyDeal((deal['id'] as num).toInt());
      _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  String _fmtDate(dynamic iso) {
    final d = DateTime.tryParse(iso?.toString() ?? '');
    if (d == null) return '-';
    return '${d.day}/${d.month}/${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final deals = (_data?['deals'] as List?)
            ?.whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList() ??
        [];

    return Scaffold(
      appBar: AppBar(title: const AppText('عروض اليوم')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const AppText('عرض جديد'),
        onPressed: () => _openForm(),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? AppStateMessage(message: _error!, onRetry: _load)
              : deals.isEmpty
                  ? const Center(child: AppText('ما عندك أي عروض يومية بعد.'))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 90),
                        itemCount: deals.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final deal = deals[i];
                          final expired = deal['is_expired'] == true;
                          final active = deal['is_active'] == true && !expired;
                          return Card(
                            elevation: 1,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: AppText(
                                          deal['product_name'] ?? 'منتج محذوف',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      ),
                                      Chip(
                                        label: AppText(
                                          active
                                              ? 'نشط'
                                              : (expired ? 'منتهي' : 'موقوف'),
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: active
                                                ? (context.isDarkTheme
                                                    ? Colors.green.shade300
                                                    : Colors.green.shade800)
                                                : (expired
                                                    ? context.mutedText
                                                    : (context.isDarkTheme
                                                        ? Colors.orange.shade300
                                                        : Colors.orange.shade900)),
                                          ),
                                        ),
                                        backgroundColor: active
                                            ? context.softTint(Colors.green)
                                            : (expired
                                                ? context.mutedSurface
                                                : context
                                                    .softTint(Colors.orange)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  AppText(
                                    'خصم ${deal['discount_percentage']}% — السعر بعد الخصم: ${(deal['discounted_price'] as num?)?.toStringAsFixed(2) ?? '-'} ل.س',
                                  ),
                                  AppText(
                                    'من ${_fmtDate(deal['starts_at'])} إلى ${_fmtDate(deal['ends_at'])}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                  if ((deal['max_quantity'] as num? ?? 0) > 0)
                                    AppText(
                                      'مباع ${deal['sold_quantity']} من ${deal['max_quantity']}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  const SizedBox(height: 10),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton.icon(
                                        onPressed: () => _toggle(deal),
                                        icon: Icon(
                                          deal['is_active'] == true
                                              ? Icons.pause_circle_outline
                                              : Icons.play_circle_outline,
                                          size: 18,
                                        ),
                                        label: AppText(
                                          deal['is_active'] == true
                                              ? 'إيقاف'
                                              : 'تشغيل',
                                        ),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _openForm(deal: deal),
                                        icon: const Icon(Icons.edit, size: 18),
                                        label: const AppText('تعديل'),
                                      ),
                                      TextButton.icon(
                                        onPressed: () => _delete(deal),
                                        icon: const Icon(
                                          Icons.delete_outline,
                                          size: 18,
                                        ),
                                        label: const AppText('حذف'),
                                        style: TextButton.styleFrom(
                                          foregroundColor: Colors.red.shade700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _DealFormSheet extends StatefulWidget {
  final List<Map<String, dynamic>> products;
  final Map<String, dynamic>? deal;

  const _DealFormSheet({required this.products, this.deal});

  @override
  State<_DealFormSheet> createState() => _DealFormSheetState();
}

class _DealFormSheetState extends State<_DealFormSheet> {
  final SellerService _service = SellerService();
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _discountCtrl;
  late final TextEditingController _specialPriceCtrl;
  late final TextEditingController _maxQtyCtrl;
  DateTime? _startsAt;
  DateTime? _endsAt;
  int? _productId;
  bool _isActive = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final deal = widget.deal;
    _discountCtrl = TextEditingController(
      text: deal != null
          ? ((deal['discount_percentage'] as num?)?.toString() ?? '')
          : '',
    );
    _specialPriceCtrl = TextEditingController(
      text: deal?['special_price']?.toString() ?? '',
    );
    _maxQtyCtrl = TextEditingController(
      text: ((deal?['max_quantity'] as num?)?.toInt() ?? 0).toString(),
    );
    _productId = deal != null ? (deal['product_id'] as num).toInt() : null;
    _startsAt = deal != null
        ? DateTime.tryParse(deal['starts_at']?.toString() ?? '')
        : null;
    _endsAt = deal != null
        ? DateTime.tryParse(deal['ends_at']?.toString() ?? '')
        : null;
    _isActive = deal?['is_active'] as bool? ?? true;
  }

  @override
  void dispose() {
    _discountCtrl.dispose();
    _specialPriceCtrl.dispose();
    _maxQtyCtrl.dispose();
    super.dispose();
  }

  String _fmt(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}'
      'T${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  Future<void> _pickDate(bool isStart) async {
    final now = DateTime.now();
    final initial = (isStart ? _startsAt : _endsAt) ?? now;
    final date = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (!mounted) return;
    final picked = DateTime(
      date.year,
      date.month,
      date.day,
      time?.hour ?? 0,
      time?.minute ?? 0,
    );
    setState(() {
      if (isStart) {
        _startsAt = picked;
      } else {
        _endsAt = picked;
      }
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_productId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('اختر منتجاً للعرض.')));
      return;
    }
    if (_startsAt == null || _endsAt == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('حدد تاريخ البداية والنهاية للعرض.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await _service.saveDailyDeal(
        id: widget.deal != null ? (widget.deal!['id'] as num).toInt() : null,
        productId: _productId!,
        discountPercentage: double.tryParse(_discountCtrl.text.trim()) ?? 0,
        specialPrice: double.tryParse(_specialPriceCtrl.text.trim()),
        startsAt: _fmt(_startsAt!),
        endsAt: _fmt(_endsAt!),
        maxQuantity: int.tryParse(_maxQtyCtrl.text.trim()) ?? 0,
        isActive: widget.deal != null ? _isActive : null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: AppText('تم حفظ العرض اليومي بنجاح.')),
      );
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: AppText(e.message)));
    } catch (_) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: AppText('تعذّر حفظ العرض.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppText(
                widget.deal == null ? 'عرض يومي جديد' : 'تعديل العرض',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<int>(
                initialValue: _productId,
                decoration: InputDecoration(
                  labelText: context.tr('المنتج'),
                  border: const OutlineInputBorder(),
                ),
                items: widget.products
                    .map(
                      (p) => DropdownMenuItem(
                        value: p['id'] as int,
                        child: AppText(
                          '${p['name']} (${(p['price'] as double).toStringAsFixed(0)} ل.س)',
                        ),
                      ),
                    )
                    .toList(),
                validator: (v) => v == null ? context.tr('اختر منتجاً') : null,
                onChanged: (v) => setState(() => _productId = v),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _discountCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr('نسبة الخصم %'),
                        border: const OutlineInputBorder(),
                      ),
                      validator: (v) {
                        final d = double.tryParse(v?.trim() ?? '');
                        if (d == null || d < 1 || d > 90) {
                          return context.tr('بين 1 و 90');
                        }
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: _specialPriceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: context.tr('سعر خاص (اختياري)'),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(true),
                      icon: const Icon(Icons.calendar_today, size: 16),
                      label: AppText(
                        _startsAt == null ? 'يبدأ في...' : _fmt(_startsAt!),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(false),
                      icon: const Icon(Icons.event, size: 16),
                      label: AppText(
                        _endsAt == null ? 'ينتهي في...' : _fmt(_endsAt!),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _maxQtyCtrl,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: context.tr('أقصى كمية (0 = غير محدودة)'),
                  border: const OutlineInputBorder(),
                ),
                validator: (v) {
                  final n = int.tryParse(v?.trim() ?? '');
                  if (n == null || n < 0) return context.tr('أدخل رقماً صحيحاً');
                  return null;
                },
              ),
              if (widget.deal != null) ...[
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const AppText('العرض مفعّل'),
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _save,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const AppText('حفظ'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
