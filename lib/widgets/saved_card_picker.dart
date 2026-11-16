import 'package:flutter/material.dart';

import '../config/theme.dart';
import '../services/payment_api.dart';
import '../l10n/app_localizations.dart';

/// نتيجة اختيار طريقة الدفع بالبطاقة: [cardId] = بطاقة محفوظة، null = بطاقة جديدة في صفحة البنك.
class CardChoice {
  const CardChoice(this.cardId);
  final int? cardId;
}

/// يعرض البطاقات المحفوظة (إن وُجدت) ليختار العميل منها أو "بطاقة جديدة".
/// يعيد null إذا أغلق العميل النافذة. بدون بطاقات محفوظة يعيد "بطاقة جديدة" مباشرة.
Future<CardChoice?> chooseCardForPayment(BuildContext context,
    {required String amountLabel, PaymentApi? api}) async {
  final payments = api ?? PaymentApi();
  List<SavedCard> cards = const [];
  try {
    final result = await payments.cards();
    if (result.enabled) {
      cards = result.cards.where((c) => !c.isExpired).toList();
    }
  } catch (_) {
    // عند تعذّر جلب البطاقات نكمل بصفحة البنك مباشرة
  }
  if (cards.isEmpty) return const CardChoice(null);
  if (!context.mounted) return null;

  return showModalBottomSheet<CardChoice>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => _CardPickerSheet(cards: cards, amountLabel: amountLabel),
  );
}

class _CardPickerSheet extends StatefulWidget {
  const _CardPickerSheet({required this.cards, required this.amountLabel});
  final List<SavedCard> cards;
  final String amountLabel;

  @override
  State<_CardPickerSheet> createState() => _CardPickerSheetState();
}

class _CardPickerSheetState extends State<_CardPickerSheet> {
  late int? _selected = widget.cards
      .firstWhere((c) => c.isDefault, orElse: () => widget.cards.first)
      .id;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppText('اختر طريقة الدفع',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            RadioGroup<int?>(
              groupValue: _selected,
              onChanged: (v) => setState(() => _selected = v),
              child: Column(
                children: [
                  for (final card in widget.cards)
                    _option(
                      value: card.id,
                      leading: BrandBadge(brand: card.brand),
                      title: card.masked,
                      subtitle:
                          '${card.brandLabel}${card.expiry != null ? ' · تنتهي ${card.expiry}' : ''}',
                    ),
                  _option(
                    value: null,
                    leading: const BrandBadge(brand: 'new'),
                    title: 'بطاقة جديدة',
                    subtitle: 'تُدخلها في صفحة البنك الآمنة',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: () => Navigator.pop(context, CardChoice(_selected)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              icon: const Icon(Icons.lock_rounded, size: 18),
              label: AppText('ادفع ${widget.amountLabel}'),
            ),
            const SizedBox(height: 8),
            AppText(
              'لا تمر بيانات البطاقة عبر التطبيق؛ نحتفظ بآخر 4 أرقام فقط.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontSize: 12, color: Theme.of(context).hintColor),
            ),
          ],
        ),
      ),
    );
  }

  Widget _option(
      {required int? value,
      required Widget leading,
      required String title,
      required String subtitle}) {
    final selected = _selected == value;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: selected ? AppColors.emerald : context.cardBorder,
            width: selected ? 1.6 : 1),
      ),
      child: RadioListTile<int?>(
        value: value,
        secondary: leading,
        title: AppText(title,
            textDirection: TextDirection.ltr,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: AppText(subtitle, style: const TextStyle(fontSize: 12)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

/// شعار مصغّر لنوع البطاقة (بدون صور خارجية).
class BrandBadge extends StatelessWidget {
  const BrandBadge({super.key, required this.brand});
  final String brand;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Widget child) = switch (brand) {
      'visa' => (
          const Color(0xFF1A1F71),
          const AppText('VISA',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontStyle: FontStyle.italic,
                  fontSize: 11))
        ),
      'mastercard' => (
          const Color(0xFF333333),
          const AppText('MC',
              style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w900,
                  fontSize: 11))
        ),
      'new' => (
          AppColors.emerald,
          const Icon(Icons.add, color: Colors.white, size: 18)
        ),
      _ => (
          AppColors.emeraldDark,
          const Icon(Icons.credit_card, color: Colors.white, size: 16)
        ),
    };
    return Container(
      width: 44,
      height: 30,
      alignment: Alignment.center,
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(6)),
      child: child,
    );
  }
}
