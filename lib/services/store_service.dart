import '../models/product.dart';
import '../models/store_coupon.dart';
import '../models/vendor.dart';
import 'api_client.dart';
import 'store_visitor_token_storage.dart';

class FollowedStoresResult {
  final List<Vendor> stores;
  final int currentPage;
  final int lastPage;
  final int total;

  const FollowedStoresResult({
    required this.stores,
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class StorePage {
  final Vendor store;
  final List<Product> products;
  final List<Product> bestSelling;
  final List<Product> recentArrivals;
  final List<Product> similarProducts;
  final List<StoreCoupon> coupons;
  final int currentPage;
  final int lastPage;
  final int total;

  const StorePage({
    required this.store,
    required this.products,
    this.bestSelling = const [],
    this.recentArrivals = const [],
    this.similarProducts = const [],
    this.coupons = const [],
    required this.currentPage,
    required this.lastPage,
    required this.total,
  });
}

class StoreService {
  StoreService({
    ApiClient? api,
    StoreVisitorTokenStorage? visitorTokens,
  })  : _api = api ?? ApiClient(),
        _visitorTokens = visitorTokens ?? StoreVisitorTokenStorage();

  final ApiClient _api;
  final StoreVisitorTokenStorage _visitorTokens;

  Future<StorePage> show(
    int storeId, {
    int page = 1,
    double? priceMin,
    double? priceMax,
    double? ratingMin,
    bool inStock = false,
  }) async {
    final visitorToken = await _visitorTokens.getOrCreate();
    final response = await _api.get(
      '/stores/$storeId',
      query: {
        'page': page,
        'price_min': priceMin,
        'price_max': priceMax,
        'rating_min': ratingMin,
        'in_stock': inStock ? 1 : null,
      },
      headers: {'X-Store-Visitor-Token': visitorToken},
    );
    if (response['visit_token'] is String) {
      await _visitorTokens.save(response['visit_token'] as String);
    }
    final storeData = response['store'];
    final productsData = response['products'];
    final featuredData = response['featured'] as Map? ?? const {};
    if (storeData is! Map ||
        productsData is! Map ||
        productsData['data'] is! List) {
      throw const FormatException('استجابة المتجر غير صالحة.');
    }

    final meta = productsData['meta'] as Map? ?? const {};
    return StorePage(
      store: Vendor.fromJson(Map<String, dynamic>.from(storeData)),
      bestSelling: _parseProducts(featuredData['best_selling']),
      recentArrivals: _parseProducts(featuredData['recent_arrivals']),
      similarProducts: _parseProducts(response['similar_products']),
      coupons: StoreCoupon.listFrom(response['coupons']),
      products: (productsData['data'] as List)
          .whereType<Map>()
          .map(
              (product) => Product.fromJson(Map<String, dynamic>.from(product)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt() ??
          (storeData['products_count'] as num?)?.toInt() ??
          0,
    );
  }

  List<Product> _parseProducts(dynamic source) {
    if (source is! List) return const [];
    return source
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<bool> toggleFollow(int storeId) async {
    return (await followToggle(storeId)).followed;
  }

  /// مثل toggleFollow مع إشارة الخادم: هل نسأل العميل عن إشعارات العروض الآن (أول متابعة).
  Future<FollowResult> followToggle(int storeId) async {
    final response = await _api.post('/stores/$storeId/follow');
    return FollowResult.fromJson(Map<String, dynamic>.from(response as Map));
  }

  Future<int> startConversation(int storeId) async {
    final response = await _api.post('/stores/$storeId/conversations');
    final data = response['data'];
    if (data is! Map || data['id'] is! num) {
      throw const FormatException('استجابة المحادثة غير صالحة.');
    }
    return (data['id'] as num).toInt();
  }

  Future<FollowedStoresResult> followedStores({int page = 1}) async {
    final response = await _api.get(
      '/profile/followed-stores',
      query: {'page': page},
    );
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('استجابة المتاجر المتابعة غير صالحة.');
    }
    final meta = response['meta'] as Map? ?? const {};
    return FollowedStoresResult(
      stores: data
          .whereType<Map>()
          .map((item) => Vendor.fromJson(Map<String, dynamic>.from(item)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      total: (meta['total'] as num?)?.toInt() ?? 0,
    );
  }
}

class FollowResult {
  final bool followed;
  final bool askOffersOptIn;

  const FollowResult({required this.followed, this.askOffersOptIn = false});

  factory FollowResult.fromJson(Map<String, dynamic> json) => FollowResult(
        followed: json['followed'] == true,
        askOffersOptIn: json['ask_offers_opt_in'] == true,
      );
}
