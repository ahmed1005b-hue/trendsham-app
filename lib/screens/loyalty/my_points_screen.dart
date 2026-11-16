import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/loyalty_service.dart';
import '../../widgets/shimmer_loading.dart';
import '../../l10n/app_localizations.dart';

/// "نقاطي": الرصيد، المعلّق، تنبيه الانتهاء، التحويل لكوبون، والسجل.
class MyPointsScreen extends StatefulWidget {
  const MyPointsScreen({super.key});

  @override
  State<MyPointsScreen> createState() => _MyPointsScreenState();
}

class _MyPointsScreenState extends State<MyPointsScreen> {
  final _service = LoyaltyService();
  final _scroll = ScrollController();

  LoyaltySummary? _summary;
  final List<LoyaltyTransaction> _items = [];
  int? _nextPage = 1;
  bool _loading = true;
  bool _loadingMore = false;
  bool _converting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 200) {
        _loadMore();
      }
    });
    _refresh();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final summary = await _service.fetchSummary();
      final page = await _service.fetchTransactions();
      if (!mounted) return;
      setState(() {
        _summary = summary;
        _items
          ..clear()
          ..addAll(page.items);
        _nextPage = page.nextPage;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل نقاطك.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    final next = _nextPage;
    if (next == null || next == 1 || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await _service.fetchTransactions(page: next);
      if (!mounted) return;
      setState(() {
        _items.addAll(page.items);
        _nextPage = page.nextPage;
      });
    } catch (_) {
      // نحاول مجدداً عند التمرير التالي
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }

  Future<void> _convert() async {
    final s = _summary;
    if (s == null || !s.canRedeem) return;
    final controller = TextEditingController(text: '${s.balance}');
    final points = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(builder: (ctx, setLocal) {
        final n = int.tryParse(controller.text) ?? 0;
        return AlertDialog(
          title: const AppText('حوّل نقاطك إلى كوبون'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(
              controller: controller,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: context.tr('عدد النقاط (${s.minRedeem} – ${s.balance})'),
              ),
              onChanged: (_) => setLocal(() {}),
            ),
            const SizedBox(height: 8),
            AppText('= ${(n * s.pointValue).toStringAsFixed(0)} ل.س، صالح ${s.couponValidDays} يوماً',
                style: const TextStyle(color: AppColors.muted, fontSize: 13)),
          ]),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const AppText('إلغاء')),
            FilledButton(
              onPressed: n >= s.minRedeem && n <= s.balance ? () => Navigator.pop(ctx, n) : null,
              child: const AppText('حوّل'),
            ),
          ],
        );
      }),
    );
    if (points == null) return;

    setState(() => _converting = true);
    try {
      final r = await _service.convert(points);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: AppText('وصلك كوبون بقيمة ${r.value.toStringAsFixed(0)} ل.س في محفظة كوبوناتك، صالح حتى ${r.expiresAt}.'),
      ));
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(e.message)));
      }
    } finally {
      if (mounted) setState(() => _converting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const AppText('نقاطي')),
      body: _loading && s == null
          ? const ListSkeleton(itemCount: 5, leadingSize: 44, circleLeading: true)
          : _error != null && s == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AppText(_error!),
                    TextButton(onPressed: _refresh, child: const AppText('إعادة المحاولة')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.all(16),
                    children: [
                      _hero(s!),
                      if (s.expiringPoints > 0) _notice(
                          Icons.hourglass_bottom_rounded,
                          '${pointsLabel(s.expiringPoints)} تنتهي قريباً (أقربها ${s.expiringAt}). استخدمها قبل ذلك.'),
                      if (s.debt > 0) _notice(Icons.info_outline,
                          'عليك ${pointsLabel(s.debt)} من طلب مرتجع، تُسدَّد تلقائياً من نقاطك القادمة.'),
                      const SizedBox(height: 12),
                      _rules(s),
                      const SizedBox(height: 12),
                      if (s.enabled)
                        FilledButton.icon(
                          onPressed: s.canRedeem && !_converting ? _convert : null,
                          icon: const Icon(Icons.confirmation_number_outlined),
                          label: AppText(s.canRedeem
                              ? 'حوّل نقاطك إلى كوبون'
                              : 'تحتاج ${s.minRedeem} نقاط للتحويل (باقي ${s.minRedeem - s.balance})'),
                        ),
                      const SizedBox(height: 20),
                      const AppText('السجل', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      const SizedBox(height: 6),
                      if (_items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: AppText('لا توجد حركات بعد. اطلب الآن واكسب أول نقاطك عند الاستلام.',
                              textAlign: TextAlign.center, style: TextStyle(color: AppColors.muted)),
                        ),
                      ..._items.map(_row),
                      if (_loadingMore)
                        const Padding(
                          padding: EdgeInsets.all(12),
                          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _hero(LoyaltySummary s) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF0B5F4A), Color(0xFF073D30)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(children: [
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const AppText('رصيدك', style: TextStyle(color: Colors.white70)),
              AppText('${s.balance}',
                  style: const TextStyle(color: Color(0xFFF1D9A0), fontSize: 34, fontWeight: FontWeight.w800)),
              AppText('قيمتها ${s.balanceValue.toStringAsFixed(0)} ل.س',
                  style: const TextStyle(color: Colors.white70, fontSize: 13)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            const AppText('معلّقة', style: TextStyle(color: Colors.white70)),
            AppText('${s.pending}',
                style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
            const AppText('عند استلام طلباتك', style: TextStyle(color: Colors.white70, fontSize: 11)),
          ]),
        ]),
      );

  Widget _notice(IconData icon, String text) => Container(
        margin: const EdgeInsets.only(top: 10),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: Colors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.orange.shade800),
          const SizedBox(width: 8),
          Expanded(child: AppText(text, style: const TextStyle(fontSize: 13))),
        ]),
      );

  Widget _rules(LoyaltySummary s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFC9962C).withValues(alpha: 0.10),
          border: Border.all(color: const Color(0xFFC9962C).withValues(alpha: 0.5)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: AppText(
          'كل ${s.spendPerPoint.toStringAsFixed(0)} ل.س تدفعها = نقطة، تُضاف عند استلام الطلب. '
          'النقطة = خصم ${s.pointValue.toStringAsFixed(0)} ل.س، تستخدمها في صفحة الدفع أو تحوّلها لكوبون.',
          style: const TextStyle(fontSize: 13, height: 1.5),
        ),
      );

  Widget _row(LoyaltyTransaction t) {
    final plus = t.points >= 0;
    final date = t.createdAt == null
        ? ''
        : '${t.createdAt!.year}-${t.createdAt!.month.toString().padLeft(2, '0')}-${t.createdAt!.day.toString().padLeft(2, '0')}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: AppText(t.label, style: const TextStyle(fontSize: 14)),
      subtitle: AppText(t.expiresAt != null ? '$date · تنتهي ${t.expiresAt}' : date,
          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
      trailing: AppText('${plus ? '+' : ''}${t.points}',
          textDirection: TextDirection.ltr,
          style: TextStyle(
              fontWeight: FontWeight.w800,
              color: plus ? const Color(0xFF0B5F4A) : AppColors.danger)),
    );
  }
}
