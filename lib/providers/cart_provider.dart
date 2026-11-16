import 'package:flutter/foundation.dart';
import '../models/cart_item.dart';
import '../services/cart_service.dart';

class CartProvider extends ChangeNotifier {
  final CartService _cartService = CartService();

  List<CartItem> _items = [];
  String _currency = 'ل.س';
  bool _isLoading = false;
  String? _error;

  List<CartItem> get items => _items;
  double get total => _items.fold(0, (sum, item) => sum + (item.unitPrice * item.quantity));
  double get subtotal => _items.fold(0, (sum, item) => sum + (item.originalUnitPrice * item.quantity));
  double get savings => _items.fold(0, (sum, item) => (item.originalUnitPrice > item.unitPrice) 
      ? sum + (item.originalUnitPrice - item.unitPrice) * item.quantity 
      : sum);
  String get currency => _currency;

  double? _pointsSpend;

  /// نقاط الولاء المتوقعة من السلة الحالية، أو null إن كان البرنامج متوقفاً
  int? get willEarnPoints => _pointsSpend == null || _pointsSpend! <= 0 ? null : (total / _pointsSpend!).floor();

  /// كم ينقص لأول نقطة
  double get pointsMissing => _pointsSpend == null ? 0 : (_pointsSpend! - total).clamp(0, double.infinity);
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final data = await _cartService.index();
      _items = data.items;
      _currency = (data.currency ?? 'SYP') == 'SYP' ? 'ل.س' : (data.currency ?? 'ل.س');
      _pointsSpend = data.pointsSpendPerPoint;
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').trim();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> add(int productId, {int quantity = 1, double? specialPrice, int? discountPercentage, int? variantId}) async {
    await _cartService.add(productId, quantity: quantity, specialPrice: specialPrice, discountPercentage: discountPercentage, variantId: variantId);
    await load();
  }

  Future<void> updateQuantity(int cartItemId, int quantity) async {
    await _cartService.updateQuantity(cartItemId, quantity);
    await load();
  }

  Future<void> remove(int cartItemId) async {
    await _cartService.remove(cartItemId);
    await load();
  }

  Future<void> clearCart() async {
    // إفراغ فوري محلياً لتجاوب واجهة المستخدم فوراً
    _items = [];
    _error = null;
    notifyListeners();

    // مزامنة مع السيرفر في الخلفية (لا يعيق واجهة المستخدم)
    _syncClearWithServer();
  }

  Future<void> _syncClearWithServer() async {
    try {
      await _cartService.clearCart();
    } catch (e) {
      _error = e.toString().replaceFirst('ApiException: ', '').trim();
      notifyListeners();
    }
  }

  void clear() {
    _items = [];
    _error = null;
    notifyListeners();
  }
}
