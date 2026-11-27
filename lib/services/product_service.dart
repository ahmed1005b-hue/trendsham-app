import '../models/category.dart' as model;
import '../models/product.dart';
import '../models/coupon_story.dart';
import '../models/product_review.dart';
import '../models/product_question.dart';
import 'api_client.dart';

class ProductService {
  final ApiClient _api = ApiClient();

  Future<List<Product>> list({
    String? categorySlug,
    String? sort,
    double? minPrice,
    double? maxPrice,
    int page = 1,
  }) async {
    final data = await _api.get('/products', withAuth: false, query: {
      'category': categorySlug,
      'sort': sort,
      'min_price': minPrice,
      'max_price': maxPrice,
      'page': page,
    });

    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }

  /// «وصل حديثاً» و«العروض» للرئيسية كما في الموقع: الأحدث مع حدّ لكل متجر،
  /// حتى لا يحتل متجر واحد الرئيسية.
  Future<({List<Product> newArrivals, List<Product> deals})>
      homeSections() async {
    final data = await _api.get('/home/products', withAuth: false);
    List<Product> parse(Object? list) => list is List
        ? list
            .whereType<Map>()
            .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
            .toList()
        : <Product>[];
    return (
      newArrivals: parse(data['new_arrivals']),
      deals: parse(data['deals'])
    );
  }

  /// منتجات بأرقامها وبنفس الترتيب («شاهدته مؤخراً»). المخفي منها لا يعود.
  Future<List<Product>> byIds(List<int> ids) async {
    if (ids.isEmpty) return [];
    final data = await _api
        .get('/products', withAuth: false, query: {'ids': ids.join(',')});
    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<Product> show(String slug) async {
    final data = await _api.get('/products/$slug');
    return Product.fromJson(data['data'] ?? data);
  }

  /// عروض اليوم النشطة من جدول daily_deals — تُستخدم في الصفحة الرئيسية.
  Future<List<Product>> dailyDeals() async {
    final data =
        await _api.get('/daily-deal', withAuth: false, query: {'all': '1'});
    final List list = data['deals'] is List ? data['deals'] as List : const [];
    return list
        .whereType<Map>()
        .where((deal) => deal['product'] is Map)
        .map((deal) {
      final product =
          Product.fromJson(Map<String, dynamic>.from(deal['product']));
      final discounted =
          double.tryParse((deal['discounted_price'] ?? '').toString());
      final pctRaw = deal['discount_percentage'];
      final pct = pctRaw is num
          ? pctRaw.toInt()
          : int.tryParse(pctRaw?.toString() ?? '');
      final endsAtRaw = deal['ends_at']?.toString();
      final endsAt = endsAtRaw == null ? null : DateTime.tryParse(endsAtRaw);
      return discounted != null && discounted > 0
          ? product.copyWithManualDeal(
              dealPrice: discounted,
              dealPercentage: pct,
              dealEndsAt: endsAt,
            )
          : product;
    }).toList();
  }

  Future<({List<ProductReview> reviews, int currentPage, int lastPage})>
      reviews(String slug, {int page = 1}) async {
    final response = await _api.get(
      '/products/$slug/reviews',
      withAuth: false,
      query: {'page': page},
    );
    if (response is! Map || response['data'] is! List) {
      throw const FormatException('استجابة تقييمات المنتج غير صالحة.');
    }

    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : const <String, dynamic>{};
    return (
      reviews: (response['data'] as List)
          .whereType<Map>()
          .map((row) => ProductReview.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
    );
  }

  Future<void> addReview(String slug,
      {required int rating, required String comment}) async {
    await _api.post(
      '/products/$slug/reviews',
      body: {
        'rating': rating,
        'comment': comment,
      },
      withAuth: true,
    );
  }

  Future<({List<Product> similar, List<Product> popular})> recommendations(
      String slug) async {
    final data = await _api.get(
      '/products/$slug/recommendations',
      withAuth: false,
    );
    if (data is! Map || data['similar'] is! List || data['popular'] is! List) {
      throw const FormatException('استجابة اقتراحات المنتجات غير صالحة.');
    }

    List<Product> parseProducts(dynamic items) => (items as List)
        .whereType<Map>()
        .map((item) => Product.fromJson(Map<String, dynamic>.from(item)))
        .toList();

    return (
      similar: parseProducts(data['similar']),
      popular: parseProducts(data['popular']),
    );
  }

  // ===== أسئلة المنتج (Soru-Cevap) =====

  Future<({List<ProductQuestion> questions, int currentPage, int lastPage})>
      questions(String slug, {int page = 1}) async {
    final response = await _api.get(
      '/products/$slug/questions',
      withAuth: false,
      query: {'page': page},
    );
    if (response is! Map || response['data'] is! List) {
      throw const FormatException('استجابة أسئلة المنتج غير صالحة.');
    }

    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : const <String, dynamic>{};
    return (
      questions: (response['data'] as List)
          .whereType<Map>()
          .map(
              (row) => ProductQuestion.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
    );
  }

  Future<ProductQuestion> askQuestion(String slug, String question) async {
    final data = await _api.post('/products/$slug/questions', body: {
      'question': question,
    });
    return ProductQuestion.fromJson(
        Map<String, dynamic>.from(data['data'] ?? data));
  }

  Future<ProductQuestionAnswer> answerQuestion(
      int questionId, String answer) async {
    final data = await _api.post('/questions/$questionId/answers', body: {
      'answer': answer,
    });
    return ProductQuestionAnswer.fromJson(
        Map<String, dynamic>.from(data['data'] ?? data));
  }

  Future<({bool isHelpful, int helpfulCount})> toggleQuestionHelpful(
      int questionId) async {
    final data = await _api.post('/questions/$questionId/helpful');
    return (
      isHelpful: data['is_helpful'] == true,
      helpfulCount: (data['helpful_count'] as num?)?.toInt() ?? 0,
    );
  }

  Future<void> deleteQuestion(int questionId) async {
    await _api.delete('/questions/$questionId');
  }

  /// بحث ذكي مع فلاتر: ترتيب، نطاق سعر، قسم، متجر، توفّر، خصم، تقييم.
  Future<({List<Product> products, int currentPage, int lastPage})> search(
      String query,
      {String? sort,
      double? minPrice,
      double? maxPrice,
      String? categorySlug,
      int? storeId,
      bool inStock = false,
      bool onSale = false,
      double? minRating,
      int page = 1}) async {
    final response = await _api.get('/search', withAuth: false, query: {
      'q': query,
      'sort': sort,
      'min_price': minPrice,
      'max_price': maxPrice,
      'category': categorySlug,
      'store': storeId,
      'in_stock': inStock ? 1 : null,
      'on_sale': onSale ? 1 : null,
      'min_rating': minRating,
      'page': page,
    });
    if (response is! Map || response['data'] is! List) {
      throw const FormatException('استجابة البحث غير صالحة.');
    }
    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : const <String, dynamic>{};
    return (
      products: (response['data'] as List)
          .whereType<Map>()
          .map((row) => Product.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
    );
  }

  /// اقتراحات فورية أثناء الكتابة
  Future<SearchSuggestions> suggestions(String query) async {
    final data = await _api
        .get('/search/suggestions', withAuth: false, query: {'q': query});
    return SearchSuggestions.fromJson(
        Map<String, dynamic>.from(data is Map ? data : const {}));
  }

  /// الكلمات الأكثر بحثاً من السيرفر
  Future<List<String>> trending() async {
    final data = await _api.get('/search/trending', withAuth: false);
    final list = data is Map ? data['trending'] : null;
    return list is List ? list.map((e) => e.toString()).toList() : const [];
  }
}

class CategoryService {
  final ApiClient _api = ApiClient();

  Future<List<model.Category>> list() async {
    final data = await _api.get('/categories', withAuth: false);
    return (data['data'] as List)
        .map((c) => model.Category.fromJson(c))
        .toList();
  }

  Future<List<Product>> products(String slug,
      {String? sort, double? minPrice, double? maxPrice}) async {
    final data = await _api.get('/categories/$slug', withAuth: false, query: {
      'sort': sort,
      'min_price': minPrice,
      'max_price': maxPrice,
    });

    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }
}

class StoryService {
  final ApiClient _api = ApiClient();

  Future<List<StoryModel>> getActiveStories() async {
    final data = await _api.get('/stories', withAuth: false);
    if (data is! Map || data['data'] is! List) {
      throw const FormatException('استجابة الستوريات غير صالحة.');
    }

    return (data['data'] as List)
        .whereType<Map>()
        .map((story) => StoryModel.fromJson(Map<String, dynamic>.from(story)))
        .where((story) => story.isActive && !story.isExpired)
        .toList();
  }
}

/// اقتراحات فورية أثناء الكتابة (منتجات + أقسام + متاجر)
class SearchSuggestions {
  final List<SuggestionItem> products;
  final List<SuggestionItem> categories;
  final List<SuggestionItem> stores;
  const SearchSuggestions({
    required this.products,
    required this.categories,
    required this.stores,
  });
  factory SearchSuggestions.fromJson(Map<String, dynamic> json) {
    List<SuggestionItem> parse(String key) => ((json[key] as List?) ?? const [])
        .whereType<Map>()
        .map((row) => SuggestionItem.fromJson(Map<String, dynamic>.from(row)))
        .toList();
    return SearchSuggestions(
      products: parse('products'),
      categories: parse('categories'),
      stores: parse('stores'),
    );
  }
  bool get isEmpty => products.isEmpty && categories.isEmpty && stores.isEmpty;
}

class SuggestionItem {
  final String? slug;
  final String? name;
  final double? price;
  final String? image;
  final int? storeId;
  const SuggestionItem(
      {this.slug, this.name, this.price, this.image, this.storeId});
  factory SuggestionItem.fromJson(Map<String, dynamic> json) {
    return SuggestionItem(
      slug: json['slug'] as String?,
      name: (json['name'] ?? json['store_name']) as String?,
      price: (json['price'] as num?)?.toDouble(),
      image: json['image'] as String?,
      storeId: (json['id'] as num?)?.toInt(),
    );
  }
}
