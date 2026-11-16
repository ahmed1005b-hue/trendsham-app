import '../models/cart_item.dart';
import 'api_client.dart';
import 'store_visitor_token_storage.dart';

class CartData {
  final List<CartItem> items;
  final double total;
  final String? currency;

  /// ل.س لكل نقطة ولاء (null = البرنامج متوقف)
  final double? pointsSpendPerPoint;

  const CartData({
    required this.items,
    required this.total,
    this.currency,
    this.pointsSpendPerPoint,
  });
}

class CartService {
  final ApiClient _api = ApiClient();
  final StoreVisitorTokenStorage _visitorTokens = StoreVisitorTokenStorage();

  Future<CartData> index() async {
    final data = await _api.get('/cart');
    final items = (data['items'] as List? ?? const [])
        .whereType<Map>()
        .map((i) => CartItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();
    return CartData(
      items: items,
      total: double.tryParse((data['total'] ?? 0).toString()) ?? 0.0,
      currency: data['currency']?.toString(),
      pointsSpendPerPoint: double.tryParse((data['points_spend_per_point'] ?? '').toString()),
    );
  }

  Future<void> add(int productId, {int quantity = 1, double? specialPrice, int? discountPercentage, int? variantId}) async {
    final token = await _visitorTokens.getOrCreate();
    await _api.post(
      '/cart',
      body: {
        'product_id': productId,
        'quantity': quantity,
        if (variantId != null) 'variant_id': variantId,
        if (specialPrice != null) 'special_price': specialPrice,
        if (discountPercentage != null) 'discount_percentage': discountPercentage,
      },
      headers: {'X-Store-Visitor-Token': token},
    );
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    await _api.put('/cart/$cartItemId', body: {'quantity': quantity});
  }

  Future<void> remove(int cartItemId) async {
    await _api.delete('/cart/$cartItemId');
  }

  Future<void> clearCart() async {
    await _api.delete('/cart');
  }
}
