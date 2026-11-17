import 'package:flutter/material.dart';

import '../screens/cart/cart_screen.dart';
import '../screens/coupons/my_coupons_screen.dart';
import '../screens/gift_cards/gift_cards_screen.dart';
import '../screens/loyalty/invite_friends_screen.dart';
import '../screens/loyalty/my_points_screen.dart';
import '../screens/messages/buyer_seller_messages_screen.dart';
import '../screens/notifications/notifications_screen.dart';
import '../screens/orders/order_detail_screen.dart';
import '../screens/product/product_detail_screen.dart';
import '../screens/returns/return_detail_screen.dart';
import '../screens/seller/seller_return_detail_screen.dart';
import '../screens/seller/seller_orders_screen.dart';
import '../screens/seller/seller_products_screen.dart';
import '../screens/seller/seller_support_screen.dart';
import '../screens/seller/seller_wallet_screen.dart';
import '../screens/store/store_screen.dart';

/// يفتح الشاشة المناسبة لإشعار ({screen, id} القادمة من الخادم)،
/// سواء ضغط المستخدم على إشعار الهاتف أو على إشعار في الجرس.
class NotificationRouter {
  NotificationRouter._();

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// الشاشة لهذا الهدف؛ أي قيمة غير معروفة أو معرّف ناقص ← قائمة الإشعارات.
  static Widget widgetFor(String? screen, String? id) {
    final intId = int.tryParse(id ?? '');
    final hasText = id != null && id.isNotEmpty;

    switch (screen) {
      case 'order':
        if (intId != null) return OrderDetailScreen(orderId: intId);
        break;
      case 'conversation':
        if (intId != null) return BuyerSellerMessagesScreen(conversationId: intId);
        break;
      case 'product':
        if (hasText) return ProductDetailScreen(slug: id);
        break;
      case 'store':
        if (intId != null) return StoreScreen(storeId: intId);
        break;
      case 'coupons':
        return const MyCouponsScreen();
      case 'points':
        return const MyPointsScreen();
      case 'cart':
        return const CartScreen();
      case 'referrals':
        return const InviteFriendsScreen();
      case 'gift_cards':
        return const GiftCardsScreen();
      case 'return':
        if (intId != null) return ReturnDetailScreen(returnId: intId);
        break;
      case 'seller_return':
        if (intId != null) return SellerReturnDetailScreen(returnId: intId);
        break;
      case 'seller_order':
        return const SellerOrdersScreen();
      case 'seller_wallet':
        return const SellerWalletScreen();
      case 'seller_products':
        return const SellerProductsScreen();
      case 'support':
        return const SellerSupportScreen();
    }
    return const NotificationsScreen();
  }

  static Future<void> open(String? screen, String? id) async {
    final nav = navigatorKey.currentState;
    if (nav == null) return;
    await nav.push(
      MaterialPageRoute(builder: (_) => widgetFor(screen, id)),
    );
  }
}
