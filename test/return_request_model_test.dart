import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/return_request.dart';

Map<String, dynamic> _json({bool full = true}) => {
      'id': 12,
      'number': 'RT-1',
      'status': 'rejected',
      'status_label': 'مرفوض',
      'reason': 'damaged',
      'reason_label': 'المنتج تالف',
      'description': 'وصل مكسوراً',
      'decision_note': 'لا يوجد ضرر',
      'order_id': 5,
      'order_number': 'TS-5',
      'store_name': 'متجر س',
      'refund_amount': 200.5,
      'shipping_refund': '10',
      'respond_by': '2026-11-19T10:00:00+00:00',
      'dispute_by': '2026-11-26T10:00:00+00:00',
      'ship_back_by': null,
      'created_at': '2026-11-16T10:00:00+00:00',
      if (full) ...{
        'items': [
          {
            'id': 1,
            'order_item_id': 9,
            'product_name': 'قميص',
            'variant_label': 'L',
            'quantity': 2,
            'refund_amount': 200.5,
          }
        ],
        'events': [
          {
            'id': 1,
            'type': 'requested',
            'label': 'تم إرسال الطلب',
            'actor_role': 'customer',
            'note': null,
            'photos': ['http://h/storage/a.jpg'],
            'created_at': '2026-11-16T10:00:00+00:00',
          },
          {'id': 2, 'type': 'rejected', 'actor_role': 'seller', 'note': 'لا'},
        ],
        'refund': {'amount': 200.5, 'method': 'wallet', 'reference': 'R1'},
        'actions': {'can_withdraw': false, 'can_dispute': true},
      },
    };

void main() {
  test('parses a full return with lines, events, photos, refund and actions',
      () {
    final r = ReturnRequest.fromJson(_json());
    expect(r.id, 12);
    expect(r.status, 'rejected');
    expect(r.refundAmount, 200.5);
    expect(r.shippingRefund, 10);
    expect(r.disputeBy, DateTime.parse('2026-11-26T10:00:00+00:00'));
    expect(r.shipBackBy, isNull);
    expect(r.items.single.productName, 'قميص');
    expect(r.items.single.quantity, 2);
    expect(r.events.length, 2);
    expect(r.events.first.photos, ['http://h/storage/a.jpg']);
    expect(r.events.last.photos, isEmpty);
    expect(r.refund!.amount, 200.5);
    expect(r.refund!.method, 'wallet');
    // سيرفر أقدم بلا method_label: يُعرض المفتاح
    expect(r.refund!.displayMethod, 'wallet');
    expect(r.canDispute, isTrue);
    expect(r.canWithdraw, isFalse);
  });

  test('list shape without items, events, refund or actions parses safely', () {
    final r = ReturnRequest.fromJson(_json(full: false));
    expect(r.items, isEmpty);
    expect(r.events, isEmpty);
    expect(r.refund, isNull);
    expect(r.canWithdraw, isFalse);
    expect(r.canDispute, isFalse);
  });

  test('parses seller fields and seller actions', () {
    final r = ReturnRequest.fromJson({
      ..._json(full: false),
      'customer_name': 'سارة',
      'actions': {
        'can_approve': true,
        'can_reject': true,
        'can_confirm_received': false,
      },
    });
    expect(r.customerName, 'سارة');
    expect(r.canApprove, isTrue);
    expect(r.canReject, isTrue);
    expect(r.canConfirmReceived, isFalse);
  });

  test('seller actions default to false', () {
    final r = ReturnRequest.fromJson(_json(full: false));
    expect(r.customerName, isNull);
    expect(r.canApprove, isFalse);
    expect(r.canReject, isFalse);
    expect(r.canConfirmReceived, isFalse);
  });

  test('ReturnsPage keeps the paginated total', () {
    const page =
        ReturnsPage(items: [], currentPage: 1, lastPage: 2, total: 7);
    expect(page.total, 7);
    expect(page.hasMore, isTrue);
  });

  test('parses returnable lines', () {
    final l = ReturnableLine.fromJson({
      'order_item_id': 9,
      'product_name': 'قميص',
      'variant_label': null,
      'unit_price': 100,
      'quantity': 3,
      'returnable_quantity': 2,
      'window_ends_at': '2026-11-20T00:00:00+00:00',
    });
    expect(l.orderItemId, 9);
    expect(l.returnableQuantity, 2);
    expect(l.unitPrice, 100);
    expect(l.windowEndsAt, isNotNull);
    expect(l.vendorId, isNull);
    expect(l.storeName, isNull);
  });

  test('returnable lines carry their store', () {
    final l = ReturnableLine.fromJson({
      'order_item_id': 9,
      'vendor_id': 4,
      'store_name': 'متجر س',
      'product_name': 'قميص',
      'unit_price': 100,
      'quantity': 1,
      'returnable_quantity': 1,
    });
    expect(l.vendorId, 4);
    expect(l.storeName, 'متجر س');
  });

  test('refund prefers the translated method label', () {
    final r = ReturnRequest.fromJson({
      ..._json(),
      'refund': {
        'amount': 50,
        'method': 'bank_transfer',
        'method_label': 'حوالة بنكية',
      },
    });
    expect(r.refund!.displayMethod, 'حوالة بنكية');
  });
}
