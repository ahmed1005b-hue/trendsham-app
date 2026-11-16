import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/services/chat_service.dart';

void main() {
  test('رسالة المساعد تقرأ البطاقات والاقتراحات', () {
    final m = ChatMessage.fromJson({
      'id': 12,
      'role': 'assistant',
      'content': 'لقيتلك 1 منتج',
      'meta': {
        'intent': 'product_search',
        'cards': [
          {
            'type': 'product',
            'id': 5,
            'slug': 'samsung-a15',
            'name': 'موبايل سامسونج',
            'price_label': '150,000 ل.س',
            'old_price_label': '180,000 ل.س',
            'image': 'http://x/storage/a.jpg',
            'in_stock': true,
          },
          {'type': 'order', 'id': 9, 'order_number': 'TS-1', 'status_label': 'قيد المراجعة', 'total_label': '10 ل.س'},
          {'type': 'link', 'title': 'محفظة الكوبونات', 'route': 'coupons'},
        ],
        'chips': ['تتبع طلبي', 'كوبوناتي'],
        'awaiting_confirmation': true,
      },
    });

    expect(m.id, 12);
    expect(m.cards, hasLength(3));
    expect(m.cards.first.type, 'product');
    expect(m.cards.first.slug, 'samsung-a15');
    expect(m.cards.first.title, 'موبايل سامسونج');
    expect(m.cards.first.subtitle, '150,000 ل.س');
    expect(m.cards.first.inStock, isTrue);
    expect(m.cards[1].id, 9);
    expect(m.cards[1].subtitle, 'قيد المراجعة');
    expect(m.cards[2].route, 'coupons');
    expect(m.chips, ['تتبع طلبي', 'كوبوناتي']);
    expect(m.awaitingConfirmation, isTrue);
    expect(m.isAgent, isFalse);
  });

  test('رد الموظف يحمل علامة الموظف واسمه', () {
    final m = ChatMessage.fromJson({
      'id': 3,
      'role': 'assistant',
      'content': 'أهلاً، أنا معك',
      'meta': {'agent': true, 'agent_name': 'ريم'},
    });

    expect(m.isAgent, isTrue);
    expect(m.agentName, 'ريم');
    expect(m.cards, isEmpty);
    expect(m.chips, isEmpty);
  });

  test('الرسائل القديمة بلا meta تبقى تعمل، وmeta الفارغة كقائمة لا تكسر القراءة', () {
    final old = ChatMessage.fromJson({'role': 'user', 'content': 'مرحبا'});
    expect(old.cards, isEmpty);
    expect(old.id, 0);

    final emptyList = ChatMessage.fromJson({'id': 1, 'role': 'assistant', 'content': 'x', 'meta': []});
    expect(emptyList.chips, isEmpty);
  });

  test('رد الإرسال قد يكون فارغاً حين تكون المحادثة عند موظف', () {
    final r = ChatSendResult.fromJson({'status': 'escalated', 'reply': null});
    expect(r.reply, isNull);
    expect(r.escalated, isTrue);
  });

  test('رد الإرسال يحمل رسالة العميل المحفوظة برقمها', () {
    final r = ChatSendResult.fromJson({
      'status': 'open',
      'message': {'id': 41, 'role': 'user', 'content': 'مرحبا', 'meta': {}},
      'reply': {'id': 42, 'role': 'assistant', 'content': 'أهلاً', 'meta': {}},
    });
    expect(r.message?.id, 41);
    expect(r.reply?.id, 42);
  });
}
