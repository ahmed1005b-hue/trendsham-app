import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/checkout_service.dart';
import 'package:trendsham/services/gift_card_service.dart';

void main() {
  test('gift cards summary reads the API shape', () {
    final s = GiftCardsSummary.fromJson({
      'balance': 15000,
      'online_enabled': true,
      'presets': [25000, 50000],
      'min_amount': 10000,
      'max_amount': 1000000,
      'cards': [
        {
          'id': 3,
          'amount': 50000,
          'status': 'active',
          'status_label': 'Ready',
          'code': 'TS-AAAA-BBBB-CCCC'
        },
        {
          'id': 4,
          'amount': 25000,
          'status': 'redeemed',
          'status_label': 'Redeemed',
          'code': null,
          'redeemed_by': 'Sam'
        },
      ],
      'transactions': [
        {
          'label': 'Gift card added',
          'amount': 50000,
          'created_at': '2026-11-17'
        },
      ],
    });

    expect(s.balance, 15000);
    expect(s.onlineEnabled, isTrue);
    expect(s.presets, [25000, 50000]);
    expect(s.cards.first.isActive, isTrue);
    expect(s.cards.last.isActive, isFalse);
    expect(s.cards.last.redeemedBy, 'Sam');
    expect(s.moves.single.amount, 50000);
  });

  test('pending card is not final yet', () {
    final c = GiftCard.fromJson(
        {'id': 1, 'amount': 10000, 'status': 'pending_payment'});
    expect(c.isFinal, isFalse);
    expect(c.isActive, isFalse);
  });

  test('checkout summary reads the gift balance', () {
    final s = CheckoutSummary.fromJson({
      'subtotal': 100,
      'shipping_fee': 150,
      'discount': 0,
      'total': 250,
      'gift_balance': 5000
    });
    expect(s.giftBalance, 5000);
    expect(
        CheckoutSummary.fromJson({'subtotal': 1, 'total': 1}).giftBalance, 0);
  });
}
