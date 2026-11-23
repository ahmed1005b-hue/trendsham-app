import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/admin_engagement_service.dart';
import '../../services/api_exception.dart';
import '../../widgets/app_state_message.dart';

/// بطاقات الهدايا للمدير (نفس صفحة الموقع): ما بيع، وما صُرف، وما بقي مستحقاً للعملاء.
/// الأكواد نفسها لا تظهر للمدير.
class AdminGiftCardsScreen extends StatefulWidget {
  const AdminGiftCardsScreen({super.key, this.service});

  /// للاختبار: خدمة بديلة بلا شبكة
  final AdminEngagementService? service;

  @override
  State<AdminGiftCardsScreen> createState() => _AdminGiftCardsScreenState();
}

class _AdminGiftCardsScreenState extends State<AdminGiftCardsScreen> {
  late final AdminEngagementService _service =
      widget.service ?? AdminEngagementService();
  final _money = NumberFormat.decimalPattern('en');
  final _search = TextEditingController();
  String? _status;
  GiftCardsPage? _page;
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
      final page =
          await _service.giftCards(status: _status, q: _search.text.trim());
      if (mounted) setState(() => _page = page);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل بطاقات الهدايا.');
    }
  }

  String _price(num? v) => '${_money.format(v ?? 0)} ل.س';

  @override
  Widget build(BuildContext context) {
    final page = _page;
    return Scaffold(
      appBar: AppBar(title: const AppText('بطاقات الهدايا')),
      body: _error != null
          ? AppStateMessage(
              message: _error!, icon: Icons.error_outline, onRetry: _load)
          : page == null
              ? const LoadingIndicator()
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _totals(page.totals),
                      const SizedBox(height: 8),
                      const AppText(
                          'الأكواد نفسها لا تظهر للمدير: يراها المشتري فقط.',
                          style:
                              TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 8),
                      Row(children: [
                        Expanded(
                          child: TextField(
                            controller: _search,
                            textInputAction: TextInputAction.search,
                            onSubmitted: (_) => _load(),
                            decoration: InputDecoration(
                                isDense: true,
                                prefixIcon: const Icon(Icons.search),
                                hintText: context.tr('بحث')),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            key: const ValueKey('gift-status-filter'),
                            initialValue: _status,
                            isDense: true,
                            items: [
                              const DropdownMenuItem(
                                  value: null, child: AppText('كل الحالات')),
                              for (final (value, label) in page.statuses)
                                DropdownMenuItem(
                                    value: value, child: AppText(label)),
                            ],
                            onChanged: (v) {
                              setState(() => _status = v);
                              _load();
                            },
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      if (page.items.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 32),
                          child: AppStateMessage(
                              message: 'لا توجد بطاقات بعد.',
                              icon: Icons.card_giftcard_outlined),
                        ),
                      for (final c in page.items)
                        Card(
                          key: ValueKey('gift-card-${c.id}'),
                          child: ListTile(
                            title: Text(c.purchaser ?? '—',
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold)),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                if (c.purchaserEmail != null)
                                  Text(c.purchaserEmail!,
                                      style: const TextStyle(fontSize: 12)),
                                if (c.redeemer != null)
                                  Row(children: [
                                    const AppText('استخدمها',
                                        style: TextStyle(fontSize: 12)),
                                    Text(': ${c.redeemer}',
                                        style: const TextStyle(fontSize: 12)),
                                  ]),
                                if (c.date != null)
                                  Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(c.date!.toLocal()),
                                      style: const TextStyle(
                                          fontSize: 11,
                                          color: AppColors.muted)),
                              ],
                            ),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                AppText(_price(c.amount),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold)),
                                AppText(c.statusLabel ?? c.status,
                                    style: const TextStyle(fontSize: 11)),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
    );
  }

  Widget _totals(Map<String, num> t) {
    final tiles = <(String, String)>[
      ('بيعت', '${t['sold_count'] ?? 0} · ${_price(t['sold_amount'])}'),
      ('صُرفت في طلبات', _price(t['spent'])),
      ('أرصدة العملاء', _price(t['balances'])),
      ('انتهت دون استخدام', _price(t['expired_unused'])),
    ];
    return Column(children: [
      Card(
        color: const Color(0xFFFFF4E0),
        child: ListTile(
          title: const AppText('مستحق على المنصة للعملاء'),
          trailing: AppText(_price(t['owed']),
              key: const ValueKey('gift-owed'),
              style:
                  const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      ),
      GridView.count(
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
      ),
    ]);
  }
}
