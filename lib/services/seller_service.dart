import '../models/category.dart';
import '../models/product.dart';
import '../models/product_options.dart';
import '../models/order.dart';
import '../models/seller_parcel.dart';
import '../models/seller_profile.dart';
import '../models/coupon_story.dart';
import '../models/seller_review.dart';
import 'package:image_picker/image_picker.dart';
import 'api_client.dart';
import 'dart:typed_data';

class SellerService {
  final ApiClient _api = ApiClient();
  Future<Map<String, dynamic>> dashboard() async {
    final data = await _api.get('/seller/dashboard');
    final Map<String, dynamic> storeMap =
        data['store'] is Map ? Map<String, dynamic>.from(data['store']) : {};
    List<Product> topProducts = [];
    if (data['top_products'] is List) {
      topProducts = (data['top_products'] as List)
          .whereType<Map>()
          .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    } else if (data['most_viewed_products'] is List) {
      topProducts = (data['most_viewed_products'] as List)
          .whereType<Map>()
          .map((p) => Product.fromJson(Map<String, dynamic>.from(p)))
          .toList();
    }

    final double totalSales = double.tryParse(
            (data['total_sales'] ?? data['sales'] ?? 0).toString()) ??
        0;
    final double commissionAmount = double.tryParse(
            (data['commission_amount'] ?? data['total_commission'] ?? 0)
                .toString()) ??
        0;
    final double netProfit = double.tryParse((data['net_profit'] ??
                data['net_earnings'] ??
                (totalSales - commissionAmount))
            .toString()) ??
        (totalSales - commissionAmount);
    List<Map<String, dynamic>> weeklySales = [];
    if (data['weekly_sales'] is List) {
      weeklySales = (data['weekly_sales'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    List<Map<String, dynamic>> monthlySales = [];
    if (data['monthly_sales'] is List) {
      monthlySales = (data['monthly_sales'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    List<Map<String, dynamic>> lowStock = [];
    if (data['low_stock_products'] is List) {
      lowStock = (data['low_stock_products'] as List)
          .whereType<Map>()
          .map((row) => Map<String, dynamic>.from(row))
          .toList();
    }
    return {
      'store': SellerProfileModel.fromJson(storeMap),
      'wallet_balance':
          double.tryParse((data['wallet_balance'] ?? 0).toString()) ?? 0,
      'products_count': (data['products_count'] as num?)?.toInt() ?? 0,
      'pending_products_count':
          (data['pending_products_count'] as num?)?.toInt() ?? 0,
      'total_sales': totalSales,
      'orders_count':
          (data['orders_count'] ?? data['total_orders'] as num?)?.toInt() ?? 0,
      'commission_amount': commissionAmount,
      'net_profit': netProfit,
      'top_products': topProducts,
      'weekly_sales': weeklySales,
      'monthly_sales': monthlySales,
      'monthly_growth': data['monthly_growth'] is num
          ? (data['monthly_growth'] as num).toDouble()
          : null,
      'total_views': (data['total_views'] as num?)?.toInt() ?? 0,
      'attributed_converting_visits':
          (data['attributed_converting_visits'] as num?)?.toInt() ?? 0,
      'attributed_orders': (data['attributed_orders'] as num?)?.toInt() ?? 0,
      'conversion_rate': (data['conversion_rate'] as num?)?.toDouble() ?? 0,
      'seller_rating': data['seller_rating'] is num
          ? (data['seller_rating'] as num).toDouble()
          : null,
      'seller_reviews_count':
          (data['seller_reviews_count'] as num?)?.toInt() ?? 0,
      'low_stock_products': lowStock,
      'low_stock_count': (data['low_stock_count'] as num?)?.toInt() ?? 0,
    };
  }

  Future<void> submitIdentityDocument(XFile document) async {
    await _api.postMultipart(
      '/seller/identity-document',
      fields: const {},
      files: {'identity_document': document},
    );
  }

  /// إدخال كمية سريع للمخزون (change موجب = إضافة، سالب = خصم؛ أو set قيمة مطلقة)
  Future<Map<String, dynamic>> quickStock(int productId,
      {int? change, int? set}) async {
    final body = <String, dynamic>{};
    if (change != null) body['change'] = change;
    if (set != null) body['set'] = set;
    final data =
        await _api.put('/seller/products/$productId/quick-stock', body: body);
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  /// قائمة المنتجات قليلة المخزون (تنبيه البائع)
  Future<List<Map<String, dynamic>>> lowStockProducts() async {
    final data = await _api.get('/seller/low-stock');
    return (data['data'] as List? ?? [])
        .whereType<Map>()
        .map((row) => Map<String, dynamic>.from(row))
        .toList();
  }

  /// تقييمات البائع لمتجر معين
  Future<StoreReviewsPage> storeReviews(int storeId, {int page = 1}) async {
    final response = await _api.get('/stores/$storeId/reviews',
        withAuth: false, query: {'page': page});
    if (response is! Map || response['data'] is! List) {
      throw const FormatException('استجابة تقييمات المتجر غير صالحة.');
    }
    final meta = response['meta'] is Map
        ? Map<String, dynamic>.from(response['meta'] as Map)
        : const <String, dynamic>{};
    return StoreReviewsPage(
      reviews: (response['data'] as List)
          .whereType<Map>()
          .map((row) =>
              SellerReviewModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      currentPage: (meta['current_page'] as num?)?.toInt() ?? page,
      lastPage: (meta['last_page'] as num?)?.toInt() ?? page,
      averageRating: (meta['average_rating'] as num?)?.toDouble(),
      reviewsCount: (meta['reviews_count'] as num?)?.toInt() ?? 0,
    );
  }

  /// إرسال تقييم للبائع بعد استلام طلب
  Future<void> submitSellerReview(int orderItemId,
      {required int rating, String? comment}) async {
    await _api.post('/order-items/$orderItemId/seller-review', body: {
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty)
        'comment': comment.trim(),
    });
  }

  /// مسودة وصف من الاسم والقسم والألوان والمقاسات (مولّد مجاني بالخادم)
  Future<String> describeProduct({
    required String name,
    int? categoryId,
    List<String> colors = const [],
    List<String> sizes = const [],
  }) async {
    final data = await _api.post('/seller/assistant/describe', body: {
      'name': name,
      if (categoryId != null) 'category_id': categoryId,
      'colors': colors,
      'sizes': sizes,
    });
    return (data is Map ? data['description'] : null)?.toString() ?? '';
  }

  Future<ProductOptionsCatalog> productOptions() async {
    final data = await _api.get('/seller/product-options');
    return ProductOptionsCatalog.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<Product>> products() async {
    final data = await _api.get('/seller/products');
    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<List<Category>> categories() async {
    final data = await _api.get('/categories', withAuth: false);
    return (data['data'] as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<void> createProduct({
    required Map<String, String> fields,
    List<XFile>? images,
  }) async {
    await _api.postMultipart('/seller/products',
        fields: fields, images: images);
  }

  Future<void> updateProduct(
    int id, {
    required Map<String, String> fields,
    List<XFile>? images,
  }) async {
    await _api.postMultipart('/seller/products/$id',
        fields: fields, images: images);
  }

  static Map<String, String> variantFields(List<Map<String, String>> variants,
      {bool replace = false}) {
    final f = <String, String>{};
    if (replace) f['replace_variants'] = '1';
    for (var i = 0; i < variants.length; i++) {
      final v = variants[i];
      void put(String k, String? val) {
        if (val != null && val.trim().isNotEmpty) f['$k[$i]'] = val.trim();
      }

      put('variant_color', v['color']);
      put('variant_color_name', v['color_name']);
      put('variant_original_color', v['original_color']);
      put('variant_size', v['size']);
      put('variant_sku', v['sku']);
      put('variant_price_adjustment', v['price_adjustment']);
      put('variant_stock_quantity', v['stock_quantity']);
      // keep index alignment by ensuring at least one key if row has any data
      if (f.containsKey('variant_color[$i]') ||
          f.containsKey('variant_size[$i]')) {
        f['variant_price_adjustment[$i]'] ??= '0';
        f['variant_stock_quantity[$i]'] ??= '0';
      }
    }
    return f;
  }

  Future<void> updateStore({
    required Map<String, String> fields,
    Map<String, XFile>? files,
  }) async {
    await _api.postMultipart(
      '/seller/store',
      fields: fields,
      files: files,
      method: 'PUT',
    );
  }

  Future<void> deleteProduct(int id) async {
    await _api.delete('/seller/products/$id');
  }

  Future<void> deleteProductImage(int productId, int imageId) async {
    await _api.delete('/seller/products/$productId/images/$imageId');
  }

  Future<void> setPrimaryImage(int productId, int imageId) async {
    await _api.post('/seller/products/$productId/images/$imageId/primary');
  }

  // ===== أسئلة العملاء على منتجاتي =====
  Future<List<Map<String, dynamic>>> questions() async {
    final data = await _api.get('/seller/questions');
    final list = data is Map ? data['questions'] : null;
    return list is List
        ? list
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
  }

  Future<void> answerQuestion(int questionId, String answer) async {
    await _api
        .post('/seller/questions/$questionId/answer', body: {'answer': answer});
  }

  // ===== مساحات العرض المؤجّرة =====
  Future<List<Map<String, dynamic>>> showcaseSlots(
      {DateTime? start, DateTime? end}) async {
    final data = await _api.get('/seller/showcase-slots', query: {
      'start_date': start == null ? null : _date(start),
      'end_date': end == null ? null : _date(end),
    });
    return data is List
        ? data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
  }

  Future<List<Map<String, dynamic>>> showcases() async {
    final data = await _api.get('/seller/showcases');
    return data is List
        ? data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList()
        : [];
  }

  Future<Map<String, dynamic>> showcase(int id) async {
    final data = await _api.get('/seller/showcases/$id');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> createShowcase({
    required int slotId,
    required DateTime start,
    required DateTime end,
    required String title,
    String? subtitle,
    required List<String> colors,
    required String direction,
    required List<int> productIds,
  }) async {
    await _api.post('/seller/showcases', body: {
      'slot_id': slotId,
      'start_date': _date(start),
      'end_date': _date(end),
      'title': title,
      if (subtitle != null && subtitle.isNotEmpty) 'subtitle': subtitle,
      'gradient_colors': colors,
      'gradient_direction': direction,
      'product_ids': productIds,
    });
  }

  Future<String> cancelShowcase(int id) async {
    final data = await _api.post('/seller/showcases/$id/cancel');
    return (data is Map ? data['message'] : null)?.toString() ??
        'تم إلغاء الحجز.';
  }

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<Map<String, dynamic>> wallet({int page = 1}) async {
    final rawData = await _api.get('/seller/wallet', query: {'page': page});
    final Map<String, dynamic> data = (rawData is Map && rawData['data'] is Map)
        ? Map<String, dynamic>.from(rawData['data'])
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : {});
    List rawTx = [];
    var currentPage = page;
    var lastPage = page;
    if (data['transactions'] != null) {
      if (data['transactions'] is List) {
        rawTx = data['transactions'] as List;
      } else if (data['transactions'] is Map &&
          data['transactions']['data'] is List) {
        rawTx = data['transactions']['data'] as List;
        final meta = data['transactions']['meta'];
        if (meta is Map) {
          currentPage = (meta['current_page'] as num?)?.toInt() ?? page;
          lastPage = (meta['last_page'] as num?)?.toInt() ?? page;
        }
      }
    }
    return {
      'balance': double.tryParse((data['balance'] ?? 0).toString()) ?? 0,
      'pending_withdrawals':
          double.tryParse((data['pending_withdrawals'] ?? 0).toString()) ?? 0,
      'available': double.tryParse(
              (data['available'] ?? data['balance'] ?? 0).toString()) ??
          0,
      'held_for_returns':
          double.tryParse((data['held_for_returns'] ?? 0).toString()) ?? 0,
      'min_withdrawal':
          double.tryParse((data['min_withdrawal'] ?? 0).toString()) ?? 0,
      'default_method': data['default_method'] is Map
          ? Map<String, dynamic>.from(data['default_method'])
          : null,
      'recent_withdrawals': (data['recent_withdrawals'] is List
              ? data['recent_withdrawals'] as List
              : const [])
          .whereType<Map>()
          .map((w) => Map<String, dynamic>.from(w))
          .toList(),
      'transactions': rawTx
          .whereType<Map>()
          .map((t) =>
              WalletTransactionModel.fromJson(Map<String, dynamic>.from(t)))
          .toList(),
      'current_page': currentPage,
      'last_page': lastPage,
    };
  }

  Future<void> requestWithdrawal(double amount, {String? note}) async {
    await _api.post('/seller/wallet/withdraw', body: {
      'amount': amount,
      if (note != null && note.trim().isNotEmpty) 'note': note.trim(),
    });
  }

  /// كل طلبات السحب مع حالتها ورقم الحوالة.
  Future<List<Map<String, dynamic>>> withdrawals() async {
    final data = await _api.get('/seller/wallet/withdrawals');
    final list =
        data is Map && data['data'] is List ? data['data'] as List : [];
    return list
        .whereType<Map>()
        .map((w) => Map<String, dynamic>.from(w))
        .toList();
  }

  Future<List<OrderItem>> orders() async {
    final rawData = await _api.get('/seller/orders');
    final List list = (rawData is Map && rawData['data'] is List)
        ? rawData['data']
        : (rawData is List
            ? rawData
            : (rawData is Map && rawData['orders'] is List
                ? rawData['orders']
                : []));
    return list
        .map((i) => OrderItem.fromJson(Map<String, dynamic>.from(i)))
        .toList();
  }

  /// مؤشرات الأداء لفترة (7 أو 14 أو 30 أو 90 يوماً) — نفس صفحة الإحصائيات في الموقع
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    final data =
        await _api.get('/seller/dashboard/analytics', query: {'days': '$days'});
    return Map<String, dynamic>.from(data);
  }

  /// تفاصيل طلب للبائع: بنود متجره فقط + طرده (طريقة التوصيل والمبلغ المطلوب)
  Future<(Order, SellerParcel)> orderDetail(int orderId) async {
    final raw =
        Map<String, dynamic>.from(await _api.get('/seller/orders/$orderId'));
    final data =
        raw['data'] is Map ? Map<String, dynamic>.from(raw['data']) : raw;
    final parcel = raw['parcel'] is Map
        ? Map<String, dynamic>.from(raw['parcel'])
        : <String, dynamic>{};
    return (Order.fromJson(data), SellerParcel.fromJson(parcel));
  }

  /// ملصق الشحنة PDF لطرد البائع في هذا الطلب (نفس ملصق الموقع)
  Future<Uint8List> parcelLabel(int orderId) =>
      _api.getBytes('/seller/orders/$orderId/label');

  Future<void> updateOrderStatus(int orderId, String status,
      {String? trackingNumber}) async {
    await _api.put('/seller/orders/$orderId/status', body: {
      'status': status,
      if (trackingNumber != null && trackingNumber.isNotEmpty)
        'tracking_number': trackingNumber,
    });
  }

  // ===== الستوري =====
  Future<Map<String, dynamic>> myStories() async {
    final rawData = await _api.get('/seller/stories');
    final Map<String, dynamic> data = (rawData is Map && rawData['data'] is Map)
        ? Map<String, dynamic>.from(rawData['data'])
        : (rawData is Map ? Map<String, dynamic>.from(rawData) : {});
    List storiesList = [];
    if (data['stories'] is List) {
      storiesList = data['stories'] as List;
    } else if (data['stories'] is Map && data['stories']['data'] is List) {
      storiesList = data['stories']['data'] as List;
    }
    return {
      'fee': double.tryParse((data['fee'] ?? 0).toString()) ?? 0,
      'wallet_balance':
          double.tryParse((data['wallet_balance'] ?? 0).toString()) ?? 0,
      'stories': storiesList
          .whereType<Map>()
          .map((s) => StoryModel.fromJson(Map<String, dynamic>.from(s)))
          .toList(),
    };
  }

  Future<void> createStory(
      {required XFile image, String? caption, String? linkUrl}) async {
    await _api.postMultipart(
      '/seller/stories',
      fields: {
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (linkUrl != null && linkUrl.isNotEmpty) 'link_url': linkUrl,
      },
      images: [image],
      imageParamName: 'image',
    );
  }

  Future<void> deleteStory(int id) async {
    await _api.delete('/seller/stories/$id');
  }

  // ===== عروض اليوم =====
  Future<Map<String, dynamic>> dailyDeals() async {
    final rawData = await _api.get('/seller/daily-deals');
    final Map<String, dynamic> data =
        rawData is Map ? Map<String, dynamic>.from(rawData) : {};
    List<Map<String, dynamic>> products = [];
    if (data['eligible_products'] is List) {
      products = (data['eligible_products'] as List)
          .whereType<Map>()
          .map((p) => Map<String, dynamic>.from(p))
          .toList();
    }
    List<Map<String, dynamic>> deals = [];
    if (data['deals'] is List) {
      deals = (data['deals'] as List)
          .whereType<Map>()
          .map((d) => Map<String, dynamic>.from(d))
          .toList();
    }
    return {'eligible_products': products, 'deals': deals};
  }

  Future<Map<String, dynamic>> saveDailyDeal({
    int? id,
    required int productId,
    required double discountPercentage,
    double? specialPrice,
    required String startsAt,
    required String endsAt,
    int maxQuantity = 0,
    bool? isActive,
  }) async {
    final body = <String, dynamic>{
      'product_id': productId,
      'discount_percentage': discountPercentage,
      if (specialPrice != null) 'special_price': specialPrice,
      'starts_at': startsAt,
      'ends_at': endsAt,
      'max_quantity': maxQuantity,
      if (isActive != null) 'is_active': isActive,
    };
    final data = id == null
        ? await _api.post('/seller/daily-deals', body: body)
        : await _api.put('/seller/daily-deals/$id', body: body);
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }

  Future<void> deleteDailyDeal(int id) async {
    await _api.delete('/seller/daily-deals/$id');
  }

  Future<Map<String, dynamic>> toggleDailyDeal(int id) async {
    final data = await _api.post('/seller/daily-deals/$id/toggle');
    return data is Map ? Map<String, dynamic>.from(data) : const {};
  }
}
