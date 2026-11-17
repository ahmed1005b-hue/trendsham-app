import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../config/theme.dart';
import '../../l10n/app_localizations.dart';
import '../../services/api_exception.dart';
import '../../services/gift_card_service.dart';
import '../../widgets/shimmer_loading.dart';

/// «بطاقات الهدايا»: الرصيد، إدخال كود، شراء بطاقة بالبنك، والبطاقات المشتراة.
class GiftCardsScreen extends StatefulWidget {
  const GiftCardsScreen({super.key});

  @override
  State<GiftCardsScreen> createState() => _GiftCardsScreenState();
}

class _GiftCardsScreenState extends State<GiftCardsScreen> {
  final _service = GiftCardService();
  final _code = TextEditingController();
  final _recipient = TextEditingController();
  final _message = TextEditingController();

  GiftCardsSummary? _summary;
  double? _amount;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  @override
  void dispose() {
    _code.dispose();
    _recipient.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final s = await _service.fetch();
      if (!mounted) return;
      setState(() {
        _summary = s;
        _amount ??= s.presets.length > 1
            ? s.presets[1]
            : (s.presets.isNotEmpty ? s.presets.first : null);
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل بطاقات الهدايا.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: AppText(message)));
  }

  Future<void> _redeem() async {
    final code = _code.text.trim();
    if (code.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final message = await _service.redeem(code);
      if (!mounted) return;
      _code.clear();
      _toast(message);
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _buy() async {
    final amount = _amount;
    if (amount == null || _busy) return;
    setState(() => _busy = true);
    try {
      final started = await _service.purchase(amount,
          recipientName: _recipient.text, message: _message.text);
      final opened = await _service.openBankPage(started.url);
      if (!opened) {
        if (mounted) _toast('تعذّر فتح صفحة البنك.');
        return;
      }
      if (mounted) _toast('أكمل الدفع في صفحة البنك، ثم عد إلى التطبيق.');
      final card = await _service.waitForPayment(started.id);
      if (!mounted) return;
      if (card?.isActive == true) {
        _recipient.clear();
        _message.clear();
        _toast('تم الدفع وبطاقة الهدية جاهزة. انسخ الكود وأرسله لمن تريد.');
      } else if (card?.status == 'failed') {
        _toast('لم يكتمل الدفع، ولم يُخصم شيء.');
      } else {
        _toast('ننتظر تأكيد البنك. ستصلك رسالة عندما تصبح البطاقة جاهزة.');
      }
      await _refresh();
    } on ApiException catch (e) {
      if (mounted) _toast(e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy(String code) async {
    await Clipboard.setData(ClipboardData(text: code));
    if (mounted) _toast('تم النسخ');
  }

  Future<void> _share(GiftCard card) async {
    final text = context.tr(
        'هدية لك من TrendSham: بطاقة بقيمة ${card.amount.toStringAsFixed(0)} ل.س. '
        'أدخل الكود ${card.code} في صفحة «بطاقات الهدايا».');
    await SharePlus.instance.share(ShareParams(
        text: card.message == null ? text : '${card.message}\n\n$text'));
  }

  @override
  Widget build(BuildContext context) {
    final s = _summary;
    return Scaffold(
      appBar: AppBar(title: const AppText('بطاقات الهدايا')),
      body: _loading && s == null
          ? const ListSkeleton(
              itemCount: 4, leadingSize: 44, circleLeading: true)
          : _error != null && s == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    AppText(_error!),
                    TextButton(
                        onPressed: _refresh,
                        child: const AppText('إعادة المحاولة')),
                  ]),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _hero(s!),
                      const SizedBox(height: 16),
                      _redeemBox(),
                      const SizedBox(height: 16),
                      _buyBox(s),
                      if (s.cards.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const AppText('بطاقات اشتريتها',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 6),
                        ...s.cards.map(_cardTile),
                      ],
                      if (s.moves.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        const AppText('حركات الرصيد',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 16)),
                        ...s.moves.map((m) => ListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(m.label),
                              subtitle: Text(m.date),
                              trailing: Text(
                                '${m.amount > 0 ? '+' : ''}${m.amount.toStringAsFixed(0)}',
                                textDirection: TextDirection.ltr,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: m.amount > 0
                                      ? AppColors.emerald
                                      : AppColors.danger,
                                ),
                              ),
                            )),
                      ],
                    ],
                  ),
                ),
    );
  }

  Widget _hero(GiftCardsSummary s) => Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
              colors: [Color(0xFF0B5F4A), Color(0xFF073D30)]),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const AppText('رصيد الهدايا',
              style: TextStyle(color: Colors.white70)),
          AppText('${s.balance.toStringAsFixed(0)} ل.س',
              style: const TextStyle(
                  color: Color(0xFFF1D9A0),
                  fontSize: 30,
                  fontWeight: FontWeight.w800)),
          const AppText('يُستخدم في صفحة الدفع، ويغطي المنتجات والشحن.',
              style: TextStyle(color: Colors.white70, fontSize: 12)),
        ]),
      );

  Widget _redeemBox() =>
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const AppText('لديك بطاقة هدية؟',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: TextField(
              controller: _code,
              textDirection: TextDirection.ltr,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                hintText: 'TS-XXXX-XXXX-XXXX',
                isDense: true,
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _redeem(),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
              onPressed: _busy ? null : _redeem,
              child: const AppText('أضف إلى رصيدي')),
        ]),
      ]);

  Widget _buyBox(GiftCardsSummary s) => Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const AppText('اشترِ بطاقة هدية',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            if (!s.onlineEnabled)
              const AppText(
                  'الدفع الإلكتروني غير متاح حالياً، لذا لا يمكن شراء بطاقات الهدايا الآن.',
                  style: TextStyle(color: AppColors.muted))
            else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: s.presets
                    .map((p) => ChoiceChip(
                          label: AppText('${p.toStringAsFixed(0)} ل.س'),
                          selected: _amount == p,
                          onSelected: (_) => setState(() => _amount = p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _recipient,
                maxLength: 60,
                decoration: InputDecoration(
                  labelText: context.tr('اسم من ستهديه (اختياري)'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _message,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: context.tr('رسالة قصيرة (اختياري)'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  counterText: '',
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFC9962C)),
                  onPressed: _busy || _amount == null ? null : _buy,
                  icon: const Icon(Icons.lock_outline),
                  label: const AppText('ادفع بالبطاقة البنكية'),
                ),
              ),
              const SizedBox(height: 6),
              const AppText(
                  'بعد الدفع يظهر لك كود البطاقة هنا، فترسله لمن تريد. صالحة للإدخال سنة كاملة.',
                  style: TextStyle(color: AppColors.muted, fontSize: 12)),
            ],
          ]),
        ),
      );

  Widget _cardTile(GiftCard c) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: AppText('${c.amount.toStringAsFixed(0)} ل.س',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Text(c.statusLabel,
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
            ]),
            if (c.recipientName != null)
              Text(c.recipientName!,
                  style: const TextStyle(color: AppColors.muted)),
            if (c.isActive) ...[
              const SizedBox(height: 6),
              Text(c.code!,
                  textDirection: TextDirection.ltr,
                  style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1)),
              Row(children: [
                TextButton.icon(
                  onPressed: () => _copy(c.code!),
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const AppText('نسخ'),
                ),
                TextButton.icon(
                  onPressed: () => _share(c),
                  icon: const Icon(Icons.share_rounded, size: 18),
                  label: const AppText('مشاركة'),
                ),
              ]),
            ] else if (c.redeemedBy != null)
              AppText('استخدمها ${c.redeemedBy} في ${c.redeemedAt}',
                  style: const TextStyle(color: AppColors.muted, fontSize: 12)),
          ]),
        ),
      );
}
