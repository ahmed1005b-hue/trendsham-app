import 'package:flutter/material.dart';

import '../../config/theme.dart';
import '../../services/api_exception.dart';
import '../../services/payment_api.dart';
import '../../widgets/app_state_message.dart';
import '../../widgets/saved_card_picker.dart';
import '../../l10n/app_localizations.dart';

/// بطاقاتي البنكية: إضافة البطاقة تتم في صفحة البنك (المتصفح)، والتطبيق لا يرى رقمها أبداً.
class SavedCardsScreen extends StatefulWidget {
  const SavedCardsScreen({super.key, this.api});
  final PaymentApi? api;

  @override
  State<SavedCardsScreen> createState() => _SavedCardsScreenState();
}

class _SavedCardsScreenState extends State<SavedCardsScreen> {
  late final PaymentApi _api = widget.api ?? PaymentApi();
  SavedCardsResult? _data;
  String? _error;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final data = await _api.cards();
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذّر تحميل البطاقات.');
    }
  }

  Future<void> _add() async {
    setState(() => _adding = true);
    try {
      final start = await _api.startAddCard();
      final opened = await _api.openCheckout(start.url);
      if (!opened) throw const ApiException('تعذّر فتح صفحة البنك.');
      final status = await _api.pollCardStatus(start.reference);
      if (!mounted) return;
      _toast(switch (status) {
        'active' => 'تم حفظ البطاقة بنجاح.',
        'failed' => 'لم يتم حفظ البطاقة.',
        _ => 'جاري تأكيد البطاقة من البنك، اسحب للتحديث بعد لحظات.',
      });
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    } finally {
      if (mounted) setState(() => _adding = false);
    }
  }

  Future<void> _setDefault(SavedCard card) async {
    try {
      await _api.setDefaultCard(card.id);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  Future<void> _delete(SavedCard card) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const AppText('حذف البطاقة'),
        content: AppText('حذف ${card.brandLabel} ${card.masked}؟'),
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
    if (ok != true) return;
    try {
      await _api.deleteCard(card.id);
      await _load();
    } on ApiException catch (e) {
      _toast(e.message);
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: AppText(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const AppText('بطاقاتي البنكية')),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.emerald,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_error != null) {
      return AppStateMessage(
          message: _error!, icon: Icons.error_outline, onRetry: _load);
    }
    final data = _data;
    if (data == null) return const LoadingIndicator();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final card in data.cards) ...[
          _BankCardView(card: card),
          Row(
            children: [
              if (!card.isDefault)
                TextButton.icon(
                  onPressed: () => _setDefault(card),
                  icon: const Icon(Icons.star_border_rounded, size: 18),
                  label: const AppText('اجعلها افتراضية'),
                ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => _delete(card),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const AppText('حذف'),
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        OutlinedButton.icon(
          onPressed: data.enabled && !_adding ? _add : null,
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          ),
          icon: _adding
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.add_card_rounded),
          label: AppText(data.enabled
              ? (_adding ? 'بانتظار صفحة البنك...' : 'إضافة بطاقة جديدة')
              : 'إضافة البطاقات ستتاح عند تفعيل الدفع الإلكتروني'),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.softTint(AppColors.emerald),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.verified_user_rounded,
                  color: AppColors.emerald, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: AppText(
                  'تُدخل بيانات البطاقة في صفحة البنك الآمنة فقط ولا تصل إلى تريندشام. '
                  'نحتفظ برمز مشفّر من البنك وآخر 4 أرقام لتدفع بضغطة واحدة.',
                  style: TextStyle(fontSize: 12.5, height: 1.6),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BankCardView extends StatelessWidget {
  const _BankCardView({required this.card});
  final SavedCard card;

  @override
  Widget build(BuildContext context) {
    final colors = switch (card.brand) {
      'visa' => const [Color(0xFF1A1F71), Color(0xFF2D5BD3)],
      'mastercard' => const [Color(0xFF222222), Color(0xFF5A5A5A)],
      _ => const [AppColors.emeraldDark, AppColors.emerald],
    };
    return Container(
      height: 170,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(18),
      ),
      child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                BrandBadge(brand: card.brand),
                const Spacer(),
                if (card.isDefault)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20)),
                    child: const AppText('افتراضية',
                        style: TextStyle(
                            color: Colors.black87,
                            fontSize: 11,
                            fontWeight: FontWeight.bold)),
                  ),
              ],
            ),
            const Spacer(),
            AppText(
              '••••  ••••  ••••  ${card.last4}',
              textDirection: TextDirection.ltr,
              style: const TextStyle(
                  fontSize: 19,
                  letterSpacing: 1.5,
                  fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Row(
              textDirection: TextDirection.ltr,
              children: [
                Expanded(
                  child: AppText(card.holderName ?? '',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12)),
                ),
                AppText(
                  card.isExpired
                      ? '${card.expiry} (منتهية)'
                      : (card.expiry ?? ''),
                  style: TextStyle(
                      fontSize: 12,
                      color:
                          card.isExpired ? Colors.amberAccent : Colors.white),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
