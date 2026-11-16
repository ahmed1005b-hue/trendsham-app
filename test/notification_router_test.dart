import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/models/notification.dart';
import 'package:trendsham/screens/coupons/my_coupons_screen.dart';
import 'package:trendsham/screens/loyalty/my_points_screen.dart';
import 'package:trendsham/screens/messages/buyer_seller_messages_screen.dart';
import 'package:trendsham/screens/notifications/notifications_screen.dart';
import 'package:trendsham/screens/orders/order_detail_screen.dart';
import 'package:trendsham/screens/product/product_detail_screen.dart';
import 'package:trendsham/screens/returns/return_detail_screen.dart';
import 'package:trendsham/screens/seller/seller_return_detail_screen.dart';
import 'package:trendsham/screens/seller/seller_orders_screen.dart';
import 'package:trendsham/screens/seller/seller_products_screen.dart';
import 'package:trendsham/screens/seller/seller_support_screen.dart';
import 'package:trendsham/screens/seller/seller_wallet_screen.dart';
import 'package:trendsham/screens/store/store_screen.dart';
import 'package:trendsham/utils/notification_router.dart';

void main() {
  group('NotificationRouter.widgetFor', () {
    test('order opens the order details with its id', () {
      final w = NotificationRouter.widgetFor('order', '14');
      expect(w, isA<OrderDetailScreen>());
      expect((w as OrderDetailScreen).orderId, 14);
    });

    test('product opens by slug, store by id, conversation by id', () {
      expect((NotificationRouter.widgetFor('product', 'red-shirt') as ProductDetailScreen).slug, 'red-shirt');
      expect((NotificationRouter.widgetFor('store', '4') as StoreScreen).storeId, 4);
      expect((NotificationRouter.widgetFor('conversation', '3') as BuyerSellerMessagesScreen).conversationId, 3);
    });

    test('returns open the customer or seller return details by id', () {
      expect((NotificationRouter.widgetFor('return', '21') as ReturnDetailScreen).returnId, 21);
      expect((NotificationRouter.widgetFor('seller_return', '22') as SellerReturnDetailScreen).returnId, 22);
      expect(NotificationRouter.widgetFor('return', null), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor('seller_return', 'x'), isA<NotificationsScreen>());
    });

    test('list screens ignore the id', () {
      expect(NotificationRouter.widgetFor('coupons', null), isA<MyCouponsScreen>());
      expect(NotificationRouter.widgetFor('points', null), isA<MyPointsScreen>());
      expect(NotificationRouter.widgetFor('seller_order', '7'), isA<SellerOrdersScreen>());
      expect(NotificationRouter.widgetFor('seller_wallet', null), isA<SellerWalletScreen>());
      expect(NotificationRouter.widgetFor('seller_products', null), isA<SellerProductsScreen>());
      expect(NotificationRouter.widgetFor('support', '8'), isA<SellerSupportScreen>());
    });

    test('unknown screen, missing id or bad id falls back to the notifications list', () {
      expect(NotificationRouter.widgetFor('notifications', null), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor('seller_coupon', '11'), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor('something_else', null), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor(null, null), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor('order', null), isA<NotificationsScreen>());
      expect(NotificationRouter.widgetFor('order', 'abc'), isA<NotificationsScreen>());
    });
  });

  test('notification model reads target from the API', () {
    final n = AppNotification.fromJson({
      'id': 1,
      'type': 'order_status_changed',
      'title': 't',
      'read': false,
      'group': 'orders',
      'target': {'screen': 'order', 'id': 14},
    });
    expect(n.targetScreen, 'order');
    expect(n.targetId, '14');

    final plain = AppNotification.fromJson({'id': 2, 'type': 'x', 'title': 't', 'read': true, 'target': null});
    expect(plain.targetScreen, isNull);
    expect(plain.targetId, isNull);
  });
}
