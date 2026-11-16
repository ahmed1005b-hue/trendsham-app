import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

class AdminDailyDealsScreen extends StatefulWidget {
  const AdminDailyDealsScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  State<AdminDailyDealsScreen> createState() => _AdminDailyDealsScreenState();
}

class _AdminDailyDealsScreenState extends State<AdminDailyDealsScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');
  List<Map<String, dynamic>>? _deals;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _service.dailyDeals();
      if (mounted) setState(() => _deals = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل عروض اليوم.');
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  Future<void> _openForm([Map<String, dynamic>? deal]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _DealForm(service: _service, deal: deal),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> deal) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الحذف'),
        content: AppText('حذف عرض "${deal['product_name']}"؟'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('حذف',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await _run(() => _service.deleteDailyDeal((deal['id'] as num).toInt()));
  }

  String _formatDate(dynamic iso) {
    final date = DateTime.tryParse('${iso ?? ''}');
    return date == null ? '-' : _dateFormat.format(date.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const AppText('عروض اليوم'),
        actions: [
          IconButton(
              tooltip: context.tr('إضافة عرض'),
              icon: const Icon(Icons.add),
              onPressed: () => _openForm()),
        ],
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
    if (_deals == null) return const LoadingIndicator();
    if (_deals!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد عروض. اضغط + لإضافة منتج اليوم.',
          icon: Icons.flash_on_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: _deals!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final d = _deals![index];
        final id = (d['id'] as num).toInt();
        final special = d['special_price'];
        return Card(
          child: ListTile(
            onTap: () => _openForm(d),
            title: AppText('${d['product_name'] ?? 'منتج محذوف'}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            // كل سطر يُترجم وحده: الأجزاء الاختيارية المتجاورة لا تُطابَق كجملة واحدة
            subtitle: AppText([
              context.tr(
                      'خصم ${(d['discount_percentage'] as num?)?.toStringAsFixed(0) ?? '-'}%') +
                  (special != null
                      ? context.tr(
                          ' • سعر خاص ${(special as num).toStringAsFixed(0)} ل.س')
                      : ''),
              '${_formatDate(d['starts_at'])} '
                  '${Directionality.of(context) == TextDirection.rtl ? '←' : '→'} '
                  '${_formatDate(d['ends_at'])}',
              if (d['max_quantity'] != null)
                context.tr(
                    'بيع ${d['sold_quantity'] ?? 0} من ${d['max_quantity']}'),
            ].join('\n')),
            isThreeLine: true,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Switch(
                  value: d['is_active'] == true,
                  activeThumbColor: AppColors.emerald,
                  onChanged: (_) => _run(() => _service.toggleDailyDeal(id)),
                ),
                IconButton(
                  tooltip: context.tr('حذف'),
                  icon:
                      const Icon(Icons.delete_outline, color: AppColors.danger),
                  onPressed: () => _delete(d),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _DealForm extends StatefulWidget {
  const _DealForm({required this.service, this.deal});

  final AdminOperationsService service;
  final Map<String, dynamic>? deal;

  @override
  State<_DealForm> createState() => _DealFormState();
}

class _DealFormState extends State<_DealForm> {
  final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');
  final _discount = TextEditingController();
  final _special = TextEditingController();
  final _maxQty = TextEditingController();
  List<Map<String, dynamic>>? _products;
  int? _productId;
  late DateTime _startsAt;
  late DateTime _endsAt;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final d = widget.deal;
    _productId = (d?['product_id'] as num?)?.toInt();
    _discount.text =
        (d?['discount_percentage'] as num?)?.toStringAsFixed(0) ?? '';
    _special.text = (d?['special_price'] as num?)?.toStringAsFixed(0) ?? '';
    _maxQty.text = d?['max_quantity']?.toString() ?? '';
    _startsAt = DateTime.tryParse('${d?['starts_at'] ?? ''}')?.toLocal() ??
        DateTime.now();
    _endsAt = DateTime.tryParse('${d?['ends_at'] ?? ''}')?.toLocal() ??
        DateTime.now().add(const Duration(days: 1));
    _loadProducts();
  }

  @override
  void dispose() {
    _discount.dispose();
    _special.dispose();
    _maxQty.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final list = await widget.service.dailyDealProducts();
      if (mounted) setState(() => _products = list);
    } catch (_) {
      if (mounted) setState(() => _products = const []);
    }
  }

  Future<void> _pick(bool start) async {
    final current = start ? _startsAt : _endsAt;
    final date = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
        context: context, initialTime: TimeOfDay.fromDateTime(current));
    if (!mounted) return;
    final value = DateTime(date.year, date.month, date.day,
        time?.hour ?? current.hour, time?.minute ?? current.minute);
    setState(() => start ? _startsAt = value : _endsAt = value);
  }

  Future<void> _save() async {
    final discount = double.tryParse(_discount.text);
    if (_productId == null || discount == null) {
      setState(() => _error = 'اختر المنتج وأدخل نسبة الخصم.');
      return;
    }
    if (!_endsAt.isAfter(_startsAt)) {
      setState(() => _error = 'يجب أن ينتهي العرض بعد بدايته.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.service.saveDailyDeal(
        id: (widget.deal?['id'] as num?)?.toInt(),
        productId: _productId!,
        discountPercentage: discount,
        specialPrice: double.tryParse(_special.text),
        startsAt: _startsAt,
        endsAt: _endsAt,
        maxQuantity: int.tryParse(_maxQty.text),
      );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final products = _products;
    return Padding(
      padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppText(widget.deal == null ? 'عرض جديد' : 'تعديل العرض',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (products == null)
              const LinearProgressIndicator()
            else
              DropdownButtonFormField<int>(
                initialValue: products.any((p) => p['id'] == _productId)
                    ? _productId
                    : null,
                isExpanded: true,
                decoration:
                    InputDecoration(labelText: l10n.translate('المنتج')),
                items: products
                    .map((p) => DropdownMenuItem<int>(
                          value: (p['id'] as num).toInt(),
                          child: AppText('${p['name']}',
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ))
                    .toList(),
                onChanged: (v) => setState(() => _productId = v),
              ),
            const SizedBox(height: 8),
            TextField(
              controller: _discount,
              keyboardType: TextInputType.number,
              decoration:
                  InputDecoration(labelText: l10n.translate('نسبة الخصم %')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _special,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.translate('سعر خاص بالليرة (اختياري)')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _maxQty,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                  labelText: l10n.translate('الكمية القصوى (اختياري)')),
            ),
            const SizedBox(height: 8),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.play_circle_outline),
              title: const AppText('يبدأ'),
              subtitle: AppText(_dateFormat.format(_startsAt)),
              onTap: () => _pick(true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.stop_circle_outlined),
              title: const AppText('ينتهي'),
              subtitle: AppText(_dateFormat.format(_endsAt)),
              onTap: () => _pick(false),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppText(_error!,
                    style: const TextStyle(color: AppColors.danger)),
              ),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              child: AppText(_saving ? 'جارٍ الحفظ...' : 'حفظ'),
            ),
          ],
        ),
      ),
    );
  }
}
