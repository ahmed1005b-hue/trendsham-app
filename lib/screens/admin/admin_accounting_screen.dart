import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../l10n/app_localizations.dart';
import '../../config/theme.dart';
import '../../services/admin_operations_service.dart';
import '../../services/api_exception.dart';
import '../../utils/file_share.dart';
import '../../widgets/app_state_message.dart';
import 'admin_reports_screen.dart' show DateRangeBar, formatMoney;

/// المحاسبة: إجماليات المنصة + أرصدة البائعين.
class AdminAccountingScreen extends StatefulWidget {
  const AdminAccountingScreen({super.key, this.service});

  final AdminOperationsService? service;

  @override
  State<AdminAccountingScreen> createState() => _AdminAccountingScreenState();
}

class _AdminAccountingScreenState extends State<AdminAccountingScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  final _search = TextEditingController();
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _totals;
  List<Map<String, dynamic>>? _sellers;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final results = await Future.wait([
        _service.accounting(_from, _to),
        _service.accountingSellers(q: _search.text.trim()),
      ]);
      if (!mounted) return;
      final dashboard = results[0] as Map<String, dynamic>;
      setState(() {
        _totals = dashboard['totals'] is Map
            ? Map<String, dynamic>.from(dashboard['totals'])
            : {};
        _sellers = results[1] as List<Map<String, dynamic>>;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل بيانات المحاسبة.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('المحاسبة')),
      body: Column(
        children: [
          DateRangeBar(
            from: _from,
            to: _to,
            onChanged: (range) {
              _from = range.start;
              _to = range.end;
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load, color: AppColors.emerald, child: _body()),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final t = _totals;
    final sellers = _sellers;
    if (t == null || sellers == null) return const LoadingIndicator();

    final stats = [
      ('المبيعات', t['sales']),
      ('العمولات', t['commissions']),
      ('المسترجعات', t['refunds']),
      ('السحوبات', t['payouts']),
      ('رسوم العرض', t['showcase']),
      ('مستحق للبائعين', t['owed_to_sellers']),
    ];

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (label, value) in stats)
              SizedBox(
                width: (MediaQuery.of(context).size.width - 32) / 2,
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        AppText(label,
                            style: const TextStyle(
                                color: AppColors.muted, fontSize: 12)),
                        AppText(formatMoney(value as num?),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 15)),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _search,
          textInputAction: TextInputAction.search,
          onSubmitted: (_) => _load(),
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: AppLocalizations.of(context)
                .translate('ابحث باسم البائع أو المتجر أو الهاتف'),
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        if (sellers.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppText('لا يوجد بائعون مطابقون.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (final s in sellers)
          Card(
            child: ListTile(
              title: AppText('${s['store_name'] ?? s['name']}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: AppText('${s['name']} • ${s['phone'] ?? ''}'),
              trailing: AppText(formatMoney(s['balance'] as num?)),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => AdminSellerLedgerScreen(
                  sellerId: (s['id'] as num).toInt(),
                  title: '${s['store_name'] ?? s['name']}',
                  service: _service,
                ),
              )),
            ),
          ),
      ],
    );
  }
}

/// كشف حساب بائع واحد: الحركات، التسوية اليدوية، الكشوف PDF وتصدير CSV.
class AdminSellerLedgerScreen extends StatefulWidget {
  const AdminSellerLedgerScreen({
    super.key,
    required this.sellerId,
    required this.title,
    this.service,
  });

  final int sellerId;
  final String title;
  final AdminOperationsService? service;

  @override
  State<AdminSellerLedgerScreen> createState() =>
      _AdminSellerLedgerScreenState();
}

class _AdminSellerLedgerScreenState extends State<AdminSellerLedgerScreen> {
  late final AdminOperationsService _service =
      widget.service ?? AdminOperationsService();
  final _dateFormat = DateFormat('yyyy/MM/dd HH:mm');
  DateTime _from = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime _to = DateTime.now();
  Map<String, dynamic>? _data;
  String? _error;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _service.sellerLedger(widget.sellerId, _from, _to);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل كشف الحساب.');
    }
  }

  Future<void> _busyRun(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on ApiException catch (e) {
      _snack(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _adjust() async {
    final amount = TextEditingController();
    final reason = TextEditingController();
    String direction = 'credit';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialog) => AlertDialog(
          title: const AppText('تسوية يدوية'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'credit', label: AppText('إضافة')),
                    ButtonSegment(value: 'debit', label: AppText('خصم')),
                  ],
                  selected: {direction},
                  onSelectionChanged: (s) =>
                      setDialog(() => direction = s.first),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: amount,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('المبلغ (ل.س)')),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: reason,
                  maxLength: 200,
                  decoration: InputDecoration(
                      labelText: AppLocalizations.of(context)
                          .translate('السبب (5 أحرف على الأقل)')),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const AppText('إلغاء')),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const AppText('تسجيل')),
          ],
        ),
      ),
    );
    final value = double.tryParse(amount.text);
    if (ok != true || value == null) return;
    await _busyRun(() async {
      await _service.adjustSeller(widget.sellerId,
          direction: direction, amount: value, reason: reason.text.trim());
      _snack('تم تسجيل التسوية.');
      await _load();
    });
  }

  Future<void> _statement() => _busyRun(() async {
        final st = await _service.createStatement(widget.sellerId, _from, _to);
        await _load();
        final id = (st['id'] as num?)?.toInt();
        if (id != null) {
          await openPdfBytes(
              await _service.statementPdf(id), '${st['number']}.pdf');
        }
      });

  Future<void> _csv() => _busyRun(() async {
        final bytes =
            await _service.sellerLedgerCsv(widget.sellerId, _from, _to);
        await shareFileBytes(
            bytes, 'ledger-seller-${widget.sellerId}.csv', 'text/csv');
      });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            AppText(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          PopupMenuButton<String>(
            enabled: !_busy && _data != null,
            onSelected: (v) {
              switch (v) {
                case 'adjust':
                  _adjust();
                case 'statement':
                  _statement();
                case 'csv':
                  _csv();
              }
            },
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'adjust', child: AppText('تسوية يدوية')),
              PopupMenuItem(
                  value: 'statement', child: AppText('إنشاء كشف PDF للفترة')),
              PopupMenuItem(value: 'csv', child: AppText('تصدير CSV')),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          DateRangeBar(
            from: _from,
            to: _to,
            onChanged: (range) {
              _from = range.start;
              _to = range.end;
              _load();
            },
          ),
          Expanded(
            child: RefreshIndicator(
                onRefresh: _load, color: AppColors.emerald, child: _body()),
          ),
        ],
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final d = _data;
    if (d == null) return const LoadingIndicator();

    final entries = (d['entries'] as List? ?? []).whereType<Map>().toList();
    final statements =
        (d['statements'] as List? ?? []).whereType<Map>().toList();

    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        Card(
          color: AppColors.emerald.withValues(alpha: 0.08),
          child: ListTile(
            title: const AppText('الرصيد الحالي'),
            trailing: AppText(formatMoney(d['balance'] as num?),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ),
        ),
        const SizedBox(height: 12),
        AppText('الحركات', style: Theme.of(context).textTheme.titleMedium),
        if (entries.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppText('لا توجد حركات في هذه الفترة.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (final e in entries)
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: AppText('${e['type_label']} • ${e['description'] ?? ''}',
                maxLines: 2, overflow: TextOverflow.ellipsis),
            subtitle: AppText(
                '${_formatDate(e['posted_at'])} • الرصيد ${formatMoney(e['balance_after'] as num?)}'),
            trailing: AppText(
              ((e['credit'] as num? ?? 0) > 0)
                  ? '+${formatMoney(e['credit'] as num?)}'
                  : '-${formatMoney(e['debit'] as num?)}',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: ((e['credit'] as num? ?? 0) > 0)
                    ? AppColors.emerald
                    : AppColors.danger,
              ),
            ),
          ),
        const SizedBox(height: 12),
        AppText('الكشوف المحفوظة',
            style: Theme.of(context).textTheme.titleMedium),
        if (statements.isEmpty)
          const Padding(
            padding: EdgeInsets.all(16),
            child: AppText('لم يُنشأ أي كشف بعد.',
                style: TextStyle(color: AppColors.muted)),
          ),
        for (final s in statements)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.picture_as_pdf_outlined),
            title: AppText('${s['number']}'),
            subtitle: AppText(
                '${s['period_from']} ← ${s['period_to']} • ختامي ${formatMoney(s['closing_balance'] as num?)}'),
            onTap: _busy
                ? null
                : () => _busyRun(() async => openPdfBytes(
                    await _service.statementPdf((s['id'] as num).toInt()),
                    '${s['number']}.pdf')),
          ),
      ],
    );
  }

  String _formatDate(dynamic iso) {
    final date = DateTime.tryParse('${iso ?? ''}');
    return date == null ? '-' : _dateFormat.format(date.toLocal());
  }
}
