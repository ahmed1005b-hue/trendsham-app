import 'package:flutter/material.dart';
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/showcase_section.dart';

/// مراجعة حجوزات مساحات العرض + إدارة المساحات (الأسعار والسعة).
class AdminShowcasesScreen extends StatelessWidget {
  const AdminShowcasesScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  Widget build(BuildContext context) {
    final svc = service ?? AdminOperationsService();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const AppText('مساحات العرض'),
          bottom: const TabBar(tabs: [
            Tab(child: AppText('الحجوزات')),
            Tab(child: AppText('المساحات')),
          ]),
        ),
        body: TabBarView(children: [
          _BookingsTab(service: svc),
          _SlotsTab(service: svc),
        ]),
      ),
    );
  }
}

Future<String?> _askReason(BuildContext context, String title) async {
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: AppText(title),
      content: TextField(
        controller: controller,
        maxLength: 200,
        decoration: InputDecoration(
            labelText: AppLocalizations.of(context).translate('السبب')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const AppText('تراجع')),
        ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const AppText('تأكيد')),
      ],
    ),
  );
  final reason = controller.text.trim();
  return ok == true && reason.isNotEmpty ? reason : null;
}

class _BookingsTab extends StatefulWidget {
  const _BookingsTab({required this.service});

  final AdminOperationsService service;

  @override
  State<_BookingsTab> createState() => _BookingsTabState();
}

class _BookingsTabState extends State<_BookingsTab> {
  String? _status = 'pending_review';
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
      final list = await widget.service.showcases(status: _status);
      if (mounted) setState(() => _items = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل الحجوزات.');
    }
  }

  Future<void> _run(Future<void> Function() action, String done) async {
    try {
      await action();
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(done)));
      }
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Row(
            children: [
              for (final entry in <String?, String>{
                null: 'الكل',
                ...kShowcaseStatusLabels,
              }.entries)
                Padding(
                  padding: const EdgeInsetsDirectional.only(end: 6),
                  child: ChoiceChip(
                    label: AppText(entry.value),
                    selected: _status == entry.key,
                    onSelected: (_) {
                      setState(() {
                        _status = entry.key;
                        _items = null;
                      });
                      _load();
                    },
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: RefreshIndicator(
              onRefresh: _load, color: AppColors.emerald, child: _list()),
        ),
      ],
    );
  }

  Widget _list() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_items == null) return const LoadingIndicator();
    if (_items!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد حجوزات بهذه الحالة.',
          icon: Icons.view_carousel_outlined);
    }

    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 16),
      itemCount: _items!.length,
      itemBuilder: (context, index) {
        final s = _items![index];
        final id = (s['id'] as num).toInt();
        final preview = s['preview'] is Map
            ? ShowcaseData.fromJson(Map<String, dynamic>.from(s['preview']))
            : null;
        return Card(
          margin: const EdgeInsets.fromLTRB(12, 10, 12, 0),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  title: AppText(
                      '${s['store_name'] ?? ''} • ${s['slot'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: AppText(
                    '${s['start_date']} ← ${s['end_date']} • ${(s['amount'] as num?)?.toStringAsFixed(0) ?? 0} ل.س'
                    '\n${kShowcaseStatusLabels[s['status']] ?? s['status']}'
                    ' • مشاهدات ${s['impressions'] ?? 0} • نقرات ${s['clicks'] ?? 0}'
                    '${s['rejection_reason'] != null ? '\nالسبب: ${s['rejection_reason']}' : ''}',
                  ),
                ),
                if (preview != null && preview.colors.length >= 2)
                  ShowcaseSection(
                    data: preview,
                    onProductTap: (_) {},
                    onStoreTap: () {},
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Wrap(
                    spacing: 8,
                    children: [
                      if (s['status'] == 'pending_review') ...[
                        ElevatedButton.icon(
                          onPressed: () => _run(
                              () => widget.service.approveShowcase(id),
                              'تمت الموافقة على العرض.'),
                          icon: const Icon(Icons.check),
                          label: const AppText('موافقة'),
                        ),
                        OutlinedButton.icon(
                          onPressed: () async {
                            final reason =
                                await _askReason(context, 'سبب الرفض');
                            if (reason == null) return;
                            await _run(
                                () => widget.service.rejectShowcase(id, reason),
                                'تم رفض العرض واسترجاع المبلغ للبائع.');
                          },
                          icon:
                              const Icon(Icons.close, color: AppColors.danger),
                          label: const AppText('رفض',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                      ],
                      if (s['status'] == 'approved')
                        OutlinedButton.icon(
                          onPressed: () async {
                            final reason =
                                await _askReason(context, 'سبب الإزالة');
                            if (reason == null) return;
                            await _run(
                                () => widget.service.removeShowcase(id, reason),
                                'تمت إزالة العرض واسترجاع المبلغ المتبقي.');
                          },
                          icon: const Icon(Icons.remove_circle_outline,
                              color: AppColors.danger),
                          label: const AppText('إزالة',
                              style: TextStyle(color: AppColors.danger)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SlotsTab extends StatefulWidget {
  const _SlotsTab({required this.service});

  final AdminOperationsService service;

  @override
  State<_SlotsTab> createState() => _SlotsTabState();
}

class _SlotsTabState extends State<_SlotsTab> {
  List<Map<String, dynamic>>? _slots;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await widget.service.showcaseSlots();
      if (mounted) setState(() => _slots = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل المساحات.');
    }
  }

  Future<void> _openForm([Map<String, dynamic>? slot]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SlotForm(service: widget.service, slot: slot),
    );
    if (saved == true) _load();
  }

  Future<void> _delete(Map<String, dynamic> slot) async {
    try {
      await widget.service.deleteShowcaseSlot((slot['id'] as num).toInt());
      await _load();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: AppText(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        tooltip: context.tr('مساحة جديدة'),
        onPressed: () => _openForm(),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
          onRefresh: _load, color: AppColors.emerald, child: _list()),
    );
  }

  Widget _list() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    if (_slots == null) return const LoadingIndicator();
    if (_slots!.isEmpty) {
      return const AppStateMessage(
          message: 'لا توجد مساحات. اضغط + لإضافة واحدة.',
          icon: Icons.dashboard_customize_outlined);
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 88),
      itemCount: _slots!.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final s = _slots![index];
        return Card(
          child: ListTile(
            onTap: () => _openForm(s),
            leading: Icon(
              s['is_active'] == true
                  ? Icons.check_circle_outline
                  : Icons.pause_circle_outline,
              color:
                  s['is_active'] == true ? AppColors.emerald : AppColors.muted,
            ),
            title: AppText('${s['name']} (${s['key']})',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: AppText(
              '${(s['price_per_day'] as num?)?.toStringAsFixed(0)} ل.س/يوم • '
              '${s['min_days']}-${s['max_days']} يوم • السعة ${s['capacity']}'
              '\nالمنتجات ${s['min_products']}-${s['max_products']} • الترتيب ${s['position']}',
            ),
            isThreeLine: true,
            trailing: IconButton(
              tooltip: context.tr('حذف'),
              icon: const Icon(Icons.delete_outline, color: AppColors.danger),
              onPressed: () => _delete(s),
            ),
          ),
        );
      },
    );
  }
}

class _SlotForm extends StatefulWidget {
  const _SlotForm({required this.service, this.slot});

  final AdminOperationsService service;
  final Map<String, dynamic>? slot;

  @override
  State<_SlotForm> createState() => _SlotFormState();
}

class _SlotFormState extends State<_SlotForm> {
  static const _fields = <(String, String, TextInputType)>[
    ('key', 'المفتاح (مثل home_top)', TextInputType.text),
    ('name', 'الاسم', TextInputType.text),
    ('position', 'الترتيب', TextInputType.number),
    ('price_per_day', 'السعر اليومي (ل.س)', TextInputType.number),
    ('min_days', 'أقل عدد أيام', TextInputType.number),
    ('max_days', 'أكثر عدد أيام', TextInputType.number),
    ('capacity', 'السعة (حجوزات متزامنة)', TextInputType.number),
    ('min_products', 'أقل عدد منتجات', TextInputType.number),
    ('max_products', 'أكثر عدد منتجات', TextInputType.number),
  ];

  late final Map<String, TextEditingController> _controllers = {
    for (final (key, _, _) in _fields)
      key: TextEditingController(text: _initial(key)),
  };
  late bool _active = widget.slot?['is_active'] != false;
  bool _saving = false;
  String? _error;

  String _initial(String key) {
    final value = widget.slot?[key];
    if (value is num) return value.toStringAsFixed(value % 1 == 0 ? 0 : 2);
    return value?.toString() ?? '';
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _error = null;
    });
    final body = <String, dynamic>{'is_active': _active};
    for (final (key, _, type) in _fields) {
      final text = _controllers[key]!.text.trim();
      body[key] = type == TextInputType.number ? num.tryParse(text) : text;
    }
    try {
      await widget.service
          .saveShowcaseSlot(body, id: (widget.slot?['id'] as num?)?.toInt());
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
            AppText(widget.slot == null ? 'مساحة جديدة' : 'تعديل المساحة',
                style:
                    const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            for (final (key, label, type) in _fields)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextField(
                  controller: _controllers[key],
                  keyboardType: type,
                  decoration: InputDecoration(labelText: l10n.translate(label)),
                ),
              ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _active,
              onChanged: (v) => setState(() => _active = v),
              title: const AppText('مفعّلة'),
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
