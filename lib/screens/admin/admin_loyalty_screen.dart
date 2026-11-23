import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_engagement_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// نقاط الولاء للمدير (نفس صفحة الموقع): الملخص، والإعدادات، والعملاء بنقاطهم.
class AdminLoyaltyScreen extends StatefulWidget {
  const AdminLoyaltyScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminEngagementService? service;

  @override
  State<AdminLoyaltyScreen> createState() => _AdminLoyaltyScreenState();
}

/// حقول الإعدادات الرقمية: (المفتاح، الاسم)
const _settingFields = <(String, String)>[
  ('loyalty_spend_per_point', 'ل.س لكل نقطة'),
  ('loyalty_point_value', 'قيمة النقطة (ل.س)'),
  ('loyalty_min_redeem', 'أقل استبدال'),
  ('loyalty_expiry_months', 'صلاحية (شهر)'),
  ('loyalty_coupon_valid_days', 'الكوبون (يوم)'),
];

class _AdminLoyaltyScreenState extends State<AdminLoyaltyScreen> {
  late final AdminEngagementService _service =
      widget.service ?? AdminEngagementService();
  final _money = NumberFormat.decimalPattern('en');
  final _search = TextEditingController();
  final Map<String, TextEditingController> _fields = {
    for (final (key, _) in _settingFields) key: TextEditingController(),
  };
  bool _enabled = true;
  LoyaltyPage? _page;
  String? _error;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load(fillSettings: true);
  }

  @override
  void dispose() {
    _search.dispose();
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load({bool fillSettings = false}) async {
    setState(() => _error = null);
    try {
      final page = await _service.loyalty(q: _search.text.trim());
      if (!mounted) return;
      setState(() {
        _page = page;
        if (fillSettings) {
          _enabled = page.settings['loyalty_enabled'] != false;
          for (final (key, _) in _settingFields) {
            _fields[key]!.text = '${page.settings[key] ?? ''}';
          }
        }
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل نقاط الولاء.');
    }
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(m)));

  Future<void> _saveSettings() async {
    final values = <String, dynamic>{'loyalty_enabled': _enabled};
    for (final (key, _) in _settingFields) {
      final n = int.tryParse(_fields[key]!.text.trim());
      if (n == null || n < 1) {
        _toast('أدخل أرقام صحيحة.');
        return;
      }
      values[key] = n;
    }
    setState(() => _saving = true);
    try {
      _toast(await _service.saveLoyaltySettings(values));
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } catch (_) {
      _toast('تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _open(LoyaltyCustomer c) async {
    await Navigator.of(context).push(MaterialPageRoute(
        builder: (_) => AdminLoyaltyCustomerScreen(
            userId: c.userId, name: c.name, service: _service)));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('نقاط الولاء')),
      body: _error != null
          ? AppStateMessage(
              message: _error!,
              icon: Icons.error_outline,
              onRetry: () => _load(fillSettings: true))
          : page == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _summary(page.summary),
                      _settings(),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _search,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) => _load(),
                        decoration: InputDecoration(
                            isDense: true,
                            prefixIcon: const Icon(Icons.search),
                            hintText: context.tr('بحث')),
                      ),
                      const SizedBox(height: 8),
                      if (page.customers.isEmpty)
                        const Padding(
                          padding: EdgeInsets.all(24),
                          child: AppText('لا يوجد عملاء بنقاط بعد.',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: AppColors.muted)),
                        ),
                      for (final c in page.customers)
                        Card(
                          key: ValueKey('loyalty-customer-${c.userId}'),
                          child: ListTile(
                            onTap: () => _open(c),
                            title: Text(c.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Text(
                                [c.phone, c.email]
                                    .whereType<String>()
                                    .where((s) => s.isNotEmpty)
                                    .join(' · '),
                                style: const TextStyle(fontSize: 12)),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${c.balance}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16)),
                                if (c.debt > 0)
                                  Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const AppText('دين',
                                            style: TextStyle(
                                                fontSize: 11,
                                                color: AppColors.danger)),
                                        Text(': ${c.debt}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.danger)),
                                      ]),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _summary(Map<String, num> s) {
    final tiles = <(String, String)>[
      (
        'النقاط القائمة',
        '${s['outstanding'] ?? 0} · ${_money.format(s['outstanding_value'] ?? 0)} ل.س'
      ),
      ('مُنحت هذا الشهر', '${s['earned_this_month'] ?? 0}'),
      ('استُبدلت هذا الشهر', '${s['redeemed_this_month'] ?? 0}'),
      ('انتهت هذا الشهر', '${s['expired_this_month'] ?? 0}'),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      childAspectRatio: 2.2,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final (label, value) in tiles)
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AppText(label,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  FittedBox(
                    child: AppText(value,
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _settings() => Card(
        margin: const EdgeInsets.only(top: 12),
        child: ExpansionTile(
          key: const ValueKey('loyalty-settings'),
          title: const AppText('إعدادات البرنامج',
              style: TextStyle(fontWeight: FontWeight.bold)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          children: [
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _enabled,
              onChanged: (v) => setState(() => _enabled = v),
              title: const AppText('البرنامج مفعّل'),
            ),
            for (final (key, label) in _settingFields)
              TextField(
                key: ValueKey('loyalty-$key'),
                controller: _fields[key],
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: context.tr(label)),
              ),
            const SizedBox(height: 12),
            FilledButton(
              key: const ValueKey('loyalty-settings-save'),
              onPressed: _saving ? null : _saveSettings,
              child: const AppText('حفظ الإعدادات'),
            ),
          ],
        ),
      );
}

/// نقاط عميل واحد: الرصيد، والمعلّق من طلبات لم تُسلَّم، والسجل، والإضافة أو الخصم بسبب.
class AdminLoyaltyCustomerScreen extends StatefulWidget {
  const AdminLoyaltyCustomerScreen(
      {super.key, required this.userId, required this.name, this.service});

  final int userId;
  final String name;
  final AdminEngagementService? service;

  @override
  State<AdminLoyaltyCustomerScreen> createState() =>
      _AdminLoyaltyCustomerScreenState();
}

class _AdminLoyaltyCustomerScreenState
    extends State<AdminLoyaltyCustomerScreen> {
  late final AdminEngagementService _service =
      widget.service ?? AdminEngagementService();
  final _points = TextEditingController();
  final _reason = TextEditingController();
  bool _add = true;
  bool _busy = false;
  String? _formError;
  LoyaltyHistory? _data;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _points.dispose();
    _reason.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.loyaltyCustomer(widget.userId);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل نقاط العميل.');
    }
  }

  Future<void> _adjust() async {
    final points = int.tryParse(_points.text.trim());
    if (points == null || points < 1) {
      setState(() => _formError = 'أدخل أرقام صحيحة.');
      return;
    }
    if (_reason.text.trim().isEmpty) {
      setState(() => _formError = 'اكتب السبب.');
      return;
    }
    setState(() {
      _busy = true;
      _formError = null;
    });
    try {
      final message = await _service.adjustPoints(widget.userId,
          add: _add, points: points, reason: _reason.text.trim());
      if (!mounted) return;
      _points.clear();
      _reason.clear();
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: AppText(message)));
      await _load();
    } on ApiException catch (e) {
      if (mounted) setState(() => _formError = e.message);
    } catch (_) {
      if (mounted) setState(() => _formError = 'تعذّر الاتصال بالسيرفر.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _data;
    return Scaffold(
      appBar: AppBar(title: Text(widget.name)),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : d == null
              ? const LoadingIndicator()
              : ListView(
                  padding: const EdgeInsets.all(12),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _stat('الرصيد', '${d.balance}'),
                            _stat('معلّقة', '${d.pending}'),
                            if (d.debt > 0) _stat('دين', '${d.debt}'),
                          ],
                        ),
                      ),
                    ),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SegmentedButton<bool>(
                              showSelectedIcon: false,
                              segments: const [
                                ButtonSegment(
                                    value: true, label: AppText('إضافة')),
                                ButtonSegment(
                                    value: false, label: AppText('خصم')),
                              ],
                              selected: {_add},
                              onSelectionChanged: (s) =>
                                  setState(() => _add = s.first),
                            ),
                            TextField(
                              key: const ValueKey('loyalty-points'),
                              controller: _points,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                  labelText: context.tr('عدد النقاط')),
                            ),
                            TextField(
                              key: const ValueKey('loyalty-reason'),
                              controller: _reason,
                              maxLength: 255,
                              decoration: InputDecoration(
                                  labelText: context.tr('السبب')),
                            ),
                            if (_formError != null)
                              AppText(_formError!,
                                  style:
                                      const TextStyle(color: AppColors.danger)),
                            FilledButton(
                              key: const ValueKey('loyalty-adjust'),
                              onPressed: _busy ? null : _adjust,
                              child: const AppText('حفظ'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const AppText('السجل',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    for (final (label, points, date) in d.transactions)
                      ListTile(
                        dense: true,
                        title: AppText(label),
                        subtitle: date == null
                            ? null
                            : Text(DateFormat('yyyy-MM-dd')
                                .format(date.toLocal())),
                        trailing: Text(points > 0 ? '+$points' : '$points',
                            textDirection: TextDirection.ltr,
                            style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: points >= 0
                                    ? AppColors.emerald
                                    : AppColors.danger)),
                      ),
                  ],
                ),
    );
  }

  Widget _stat(String label, String value) => Column(children: [
        AppText(label,
            style: const TextStyle(fontSize: 12, color: AppColors.muted)),
        Text(value,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
      ]);
}
