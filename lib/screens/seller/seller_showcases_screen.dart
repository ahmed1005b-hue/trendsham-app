import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../models/product.dart';
import '../../services/api_exception.dart';
import '../../services/seller_service.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/showcase_section.dart';

String _money(num? v) => '${NumberFormat('#,##0.##').format(v ?? 0)} ل.س';

/// حجوزات مساحات العرض الخاصة بالبائع.
class SellerShowcasesScreen extends StatefulWidget {
  const SellerShowcasesScreen({super.key, this.service});

  final SellerService? service;

  @override
  State<SellerShowcasesScreen> createState() => _SellerShowcasesScreenState();
}

class _SellerShowcasesScreenState extends State<SellerShowcasesScreen> {
  late final SellerService _service = widget.service ?? SellerService();
  List<Map<String, dynamic>>? _items;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await _service.showcases();
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الحجوزات.');
    }
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(MaterialPageRoute(
        builder: (_) => SellerShowcaseCreateScreen(service: _service)));
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('مساحات العرض')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        icon: const Icon(Icons.add),
        label: const AppText('حجز مساحة'),
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _body()),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_items == null) return const LoadingIndicator();
    if (_items!.isEmpty) {
      return const AppStateMessage(
          message:
              'لم تحجز أي مساحة بعد. احجز مساحة لتظهر منتجاتك في الصفحة الرئيسية.',
          icon: Icons.view_carousel_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: _items!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _items![index];
        return Card(
          child: ListTile(
            title: AppText('${s['title']} • ${s['slot']}',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: AppText(
              '${s['start_date']} ← ${s['end_date']} • ${_money(s['amount'] as num?)}'
              '\n${kShowcaseStatusLabels[s['status']] ?? s['status']}'
              ' • مشاهدات ${s['impressions'] ?? 0} • نقرات ${s['clicks'] ?? 0} (${s['ctr'] ?? 0}%)',
            ),
            isThreeLine: true,
            trailing: const Icon(Icons.chevron_left),
            onTap: () async {
              await Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => _ShowcaseDetailScreen(
                    id: (s['id'] as num).toInt(), service: _service),
              ));
              _load();
            },
          ),
        );
      },
    );
  }
}

class _ShowcaseDetailScreen extends StatefulWidget {
  const _ShowcaseDetailScreen({required this.id, required this.service});

  final int id;
  final SellerService service;

  @override
  State<_ShowcaseDetailScreen> createState() => _ShowcaseDetailScreenState();
}

class _ShowcaseDetailScreenState extends State<_ShowcaseDetailScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _cancelling = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await widget.service.showcase(widget.id);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الحجز.');
    }
  }

  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('إلغاء الحجز'),
        content: const AppText(
            'سيُلغى الحجز ويُعاد المبلغ كاملاً إلى محفظتك. يمكن الإلغاء فقط قبل بدء فترة العرض.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('إلغاء الحجز',
                  style: TextStyle(color: AppColors.danger))),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _cancelling = true);
    try {
      final message = await widget.service.cancelShowcase(widget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    final start = DateTime.tryParse('${d?['start_date'] ?? ''}');
    final today = DateUtils.dateOnly(DateTime.now());
    final canCancel = d != null &&
        (d['status'] == 'pending_review' || d['status'] == 'approved') &&
        start != null &&
        start.isAfter(today);
    final preview = d?['preview'] is Map
        ? ShowcaseData.fromJson(Map<String, dynamic>.from(d!['preview']))
        : null;

    return Scaffold(
      appBar: AppBar(title: AppText('${d?['title'] ?? 'الحجز'}')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : d == null
              ? const LoadingIndicator()
              : ListView(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  children: [
                    if (preview != null)
                      ShowcaseSection(
                          data: preview,
                          onProductTap: (_) {},
                          onStoreTap: () {}),
                    ListTile(
                      title: const AppText('الحالة'),
                      trailing: AppText(kShowcaseStatusLabels[d['status']] ??
                          '${d['status']}'),
                    ),
                    if (d['rejection_reason'] != null)
                      ListTile(
                        title: const AppText('سبب الرفض/الإزالة'),
                        subtitle: AppText('${d['rejection_reason']}'),
                      ),
                    ListTile(
                      title: const AppText('المساحة والفترة'),
                      subtitle: AppText(
                          '${d['slot']} • ${d['start_date']} ← ${d['end_date']}'),
                      trailing: AppText(_money(d['amount'] as num?)),
                    ),
                    ListTile(
                      title: const AppText('الأداء'),
                      subtitle: AppText(
                          'مشاهدات ${d['impressions'] ?? 0} • نقرات ${d['clicks'] ?? 0} • نسبة النقر ${d['ctr'] ?? 0}%'),
                    ),
                    if (canCancel)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: OutlinedButton.icon(
                          onPressed: _cancelling ? null : _cancel,
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppColors.danger),
                          label: const AppText('إلغاء الحجز واسترجاع المبلغ',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ),
                  ],
                ),
    );
  }
}

/// حجز مساحة عرض جديدة: الفترة ← المساحة ← التصميم ← المنتجات، مع معاينة حية.
class SellerShowcaseCreateScreen extends StatefulWidget {
  const SellerShowcaseCreateScreen({super.key, this.service});

  final SellerService? service;

  @override
  State<SellerShowcaseCreateScreen> createState() =>
      _SellerShowcaseCreateScreenState();
}

class _SellerShowcaseCreateScreenState
    extends State<SellerShowcaseCreateScreen> {
  late final SellerService _service = widget.service ?? SellerService();
  final _dateFormat = DateFormat('yyyy/MM/dd');
  final _title = TextEditingController();
  final _subtitle = TextEditingController();

  DateTimeRange? _range;
  List<Map<String, dynamic>>? _slots;
  bool _loadingSlots = false;
  Map<String, dynamic>? _slot;
  List<String> _colors = kGradientPresets.first.$2;
  String _direction = 'diagonal';
  List<Product>? _products;
  final Set<int> _selected = {};
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title.addListener(() => setState(() {}));
    _subtitle.addListener(() => setState(() {}));
    _loadProducts();
  }

  @override
  void dispose() {
    _title.dispose();
    _subtitle.dispose();
    super.dispose();
  }

  Future<void> _loadProducts() async {
    try {
      final all = await _service.products();
      if (!mounted) return;
      setState(() => _products = all
          .where((p) => p.status == 'active' && p.stockQuantity > 0)
          .toList());
    } catch (_) {
      if (mounted) setState(() => _products = const []);
    }
  }

  Future<void> _pickRange() async {
    final today = DateUtils.dateOnly(DateTime.now());
    final range = await showDateRangePicker(
      context: context,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365)),
      initialDateRange: _range,
    );
    if (range == null) return;
    setState(() {
      _range = range;
      _slot = null;
      _loadingSlots = true;
    });
    try {
      final slots =
          await _service.showcaseSlots(start: range.start, end: range.end);
      if (mounted) setState(() => _slots = slots);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loadingSlots = false);
    }
  }

  int get _minProducts => (_slot?['min_products'] as num?)?.toInt() ?? 5;
  int get _maxProducts => (_slot?['max_products'] as num?)?.toInt() ?? 10;

  (bool, double) get _contrast => ColorContrast.pick(_colors);

  String? _validate() {
    if (_range == null) return 'اختر فترة العرض.';
    if (_slot == null) return 'اختر مساحة متاحة.';
    final days = (_slot!['days'] as num?)?.toInt() ?? 0;
    final minDays = (_slot!['min_days'] as num?)?.toInt() ?? 1;
    final maxDays = (_slot!['max_days'] as num?)?.toInt() ?? 365;
    if (days < minDays || days > maxDays) {
      return 'مدة هذه المساحة من $minDays إلى $maxDays يوم.';
    }
    if (_title.text.trim().isEmpty) return 'اكتب عنواناً للعرض.';
    if (_contrast.$2 < 3) {
      return 'هذه الألوان لا تسمح بقراءة النص بوضوح. اختر ألواناً أخرى.';
    }
    if (_selected.length < _minProducts || _selected.length > _maxProducts) {
      return 'اختر من $_minProducts إلى $_maxProducts منتجات.';
    }
    return null;
  }

  Future<void> _submit() async {
    final problem = _validate();
    if (problem != null) {
      setState(() => _error = problem);
      return;
    }
    final total = _slot!['total'] as num?;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('تأكيد الحجز'),
        content: AppText(
            'سيُخصم ${_money(total)} من محفظتك ويُرسل العرض لمراجعة الإدارة. '
            'إن رُفض يُعاد المبلغ كاملاً.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const AppText('تراجع')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const AppText('تأكيد ودفع')),
        ],
      ),
    );
    if (ok != true) return;

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await _service.createShowcase(
        slotId: (_slot!['id'] as num).toInt(),
        start: _range!.start,
        end: _range!.end,
        title: _title.text.trim(),
        subtitle: _subtitle.text.trim(),
        colors: _colors,
        direction: _direction,
        productIds: _selected.toList(),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: AppText('تم إرسال الحجز للمراجعة.')));
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  ShowcaseData _previewData() {
    final chosen = (_products ?? const <Product>[])
        .where((p) => _selected.contains(p.id))
        .toList();
    return ShowcaseData.fromJson({
      'id': 0,
      'placement': _slot?['key'] ?? '',
      'title': _title.text.trim().isEmpty ? 'عنوان العرض' : _title.text.trim(),
      'subtitle': _subtitle.text.trim(),
      'gradient': {'colors': _colors, 'direction': _direction},
      'text_color': _contrast.$1 ? 'light' : 'dark',
      'store': {'id': 0, 'name': '', 'logo_url': null},
      'products': [
        for (final p in chosen)
          {
            'id': p.id,
            'slug': p.slug,
            'name': p.name,
            'price': p.price,
            'old_price': p.compareAtPrice,
            'image_url': p.primaryImage?.url,
          },
      ],
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final contrast = _contrast;
    return Scaffold(
      appBar: AppBar(title: const AppText('حجز مساحة عرض')),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          ShowcaseSection(
              data: _previewData(), onProductTap: (_) {}, onStoreTap: () {}),
          _section('1. فترة العرض'),
          ListTile(
            leading: const Icon(Icons.date_range),
            title: AppText(_range == null
                ? 'اختر تاريخ البداية والنهاية'
                : '${_dateFormat.format(_range!.start)} ← ${_dateFormat.format(_range!.end)}'),
            onTap: _pickRange,
          ),
          if (_range != null) ...[
            _section('2. المساحة'),
            if (_loadingSlots)
              const Padding(
                  padding: EdgeInsets.all(16), child: LinearProgressIndicator())
            else if ((_slots ?? const []).isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: AppText('لا توجد مساحات مفعّلة حالياً.',
                    style: TextStyle(color: AppColors.muted)),
              )
            else
              for (final s in _slots!)
                ListTile(
                  enabled: s['available'] != false,
                  selected: _slot?['id'] == s['id'],
                  leading: Icon(_slot?['id'] == s['id']
                      ? Icons.radio_button_checked
                      : Icons.radio_button_unchecked),
                  onTap: () => setState(() => _slot = s),
                  title: AppText('${s['name']}'),
                  subtitle: AppText(s['available'] == false
                      ? 'محجوزة بالكامل في هذه الفترة'
                      : '${_money(s['price_per_day'] as num?)}/يوم • ${s['days']} يوم = ${_money(s['total'] as num?)}'
                          '\n${s['min_products']}-${s['max_products']} منتجات • ${s['min_days']}-${s['max_days']} يوم'),
                  isThreeLine: s['available'] != false,
                ),
          ],
          _section('3. التصميم'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                TextField(
                  controller: _title,
                  maxLength: 60,
                  decoration:
                      InputDecoration(labelText: l10n.translate('العنوان')),
                ),
                TextField(
                  controller: _subtitle,
                  maxLength: 100,
                  decoration: InputDecoration(
                      labelText: l10n.translate('وصف قصير (اختياري)')),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 64,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: kGradientPresets.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (_, i) {
                final (name, colors) = kGradientPresets[i];
                final selected = colors.join() == _colors.join();
                return Tooltip(
                  message: name,
                  child: InkWell(
                    onTap: () => setState(() => _colors = colors),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 56,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          for (final c in colors)
                            Color(int.parse(c.replaceFirst('#', '0xFF'))),
                        ]),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 3,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'diagonal', label: AppText('مائل')),
                ButtonSegment(value: 'horizontal', label: AppText('أفقي')),
                ButtonSegment(value: 'vertical', label: AppText('عمودي')),
              ],
              selected: {_direction},
              onSelectionChanged: (s) => setState(() => _direction = s.first),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: AppText(
              contrast.$2 >= 3
                  ? 'وضوح النص: جيد (${contrast.$2.toStringAsFixed(1)})'
                  : 'وضوح النص ضعيف (${contrast.$2.toStringAsFixed(1)}) — اختر ألواناً أخرى',
              style: TextStyle(
                  fontSize: 12,
                  color:
                      contrast.$2 >= 3 ? AppColors.emerald : AppColors.danger),
            ),
          ),
          _section(
              '4. المنتجات (${_selected.length}/$_minProducts-$_maxProducts)'),
          if (_products == null)
            const Padding(
                padding: EdgeInsets.all(16), child: LinearProgressIndicator())
          else if (_products!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: AppText(
                  'لا توجد منتجات فعّالة ومتوفرة في متجرك. يجب أن تكون المنتجات معتمدة وفي المخزون.',
                  style: TextStyle(color: AppColors.muted)),
            )
          else
            for (final p in _products!)
              CheckboxListTile(
                value: _selected.contains(p.id),
                onChanged: (v) => setState(() {
                  if (v == true) {
                    if (_selected.length < _maxProducts) _selected.add(p.id);
                  } else {
                    _selected.remove(p.id);
                  }
                }),
                title: AppText(p.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: AppText(p.formattedPrice),
              ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: AppText(_error!,
                  style: const TextStyle(color: AppColors.danger)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: FilledButton.icon(
              onPressed: _submitting ? null : _submit,
              icon: const Icon(Icons.send),
              label: AppText(_submitting ? 'جارٍ الإرسال...' : 'إرسال الحجز'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _section(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: AppText(title, style: Theme.of(context).textTheme.titleMedium),
      );
}
