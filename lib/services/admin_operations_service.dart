import 'dart:typed_data';

import '../models/order.dart';
import 'api_client.dart';

List<Map<String, dynamic>> _list(dynamic data, [String key = 'data']) {
  final raw = data is Map ? data[key] : data;
  return raw is List
      ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
      : <Map<String, dynamic>>[];
}

Map<String, dynamic> _item(dynamic data) =>
    data is Map && data['data'] is Map
        ? Map<String, dynamic>.from(data['data'] as Map)
        : <String, dynamic>{};

/// عمليات المدير المقابلة لصفحات الويب: الشحن، الدفع اليدوي، عروض اليوم،
/// مساحات العرض، دعم البائعين، التقارير والمحاسبة.
class AdminOperationsService {
  AdminOperationsService({ApiClient? api}) : _api = api ?? ApiClient();

  final ApiClient _api;

  // ===== شركات الشحن + شحنة الطلب =====
  Future<List<Map<String, dynamic>>> shippingCompanies() async =>
      _list(await _api.get('/admin/shipping-companies'));

  Future<void> createShippingCompany(String name, {String? phone}) =>
      _api.post('/admin/shipping-companies', body: {
        'name': name,
        if (phone != null && phone.isNotEmpty) 'phone': phone,
      });

  Future<void> toggleShippingCompany(int id) =>
      _api.post('/admin/shipping-companies/$id/toggle');

  Future<void> deleteShippingCompany(int id) =>
      _api.delete('/admin/shipping-companies/$id');

  Future<Order> updateShipment(
    int orderId,
    int shipmentId, {
    required String status,
    int? shippingCompanyId,
    String? trackingNumber,
  }) async {
    final data = await _api.put('/admin/orders/$orderId/shipments/$shipmentId',
        body: {
          'status': status,
          'shipping_company_id': shippingCompanyId,
          'tracking_number': trackingNumber,
        });
    return Order.fromJson(data['data'] ?? data);
  }

  // ===== الدفع اليدوي =====
  Future<Order> markPaid(int orderId, {String? transactionRef}) async {
    final data = await _api.post('/admin/orders/$orderId/payment/mark-paid',
        body: {
          if (transactionRef != null && transactionRef.isNotEmpty)
            'transaction_ref': transactionRef,
        });
    return Order.fromJson(data['data'] ?? data);
  }

  Future<Order> markFailed(int orderId) async {
    final data = await _api.post('/admin/orders/$orderId/payment/mark-failed');
    return Order.fromJson(data['data'] ?? data);
  }

  // ===== عروض اليوم =====
  Future<List<Map<String, dynamic>>> dailyDeals() async =>
      _list(await _api.get('/admin/daily-deals'));

  Future<List<Map<String, dynamic>>> dailyDealProducts() async =>
      _list(await _api.get('/admin/daily-deals/products'));

  Future<void> saveDailyDeal({
    int? id,
    required int productId,
    required double discountPercentage,
    double? specialPrice,
    required DateTime startsAt,
    required DateTime endsAt,
    int? maxQuantity,
  }) {
    final body = {
      'product_id': productId,
      'discount_percentage': discountPercentage,
      'special_price': specialPrice,
      'starts_at': startsAt.toIso8601String(),
      'ends_at': endsAt.toIso8601String(),
      'max_quantity': maxQuantity,
    };
    return id == null
        ? _api.post('/admin/daily-deals', body: body)
        : _api.put('/admin/daily-deals/$id', body: body);
  }

  Future<void> toggleDailyDeal(int id) =>
      _api.post('/admin/daily-deals/$id/toggle');

  Future<void> deleteDailyDeal(int id) => _api.delete('/admin/daily-deals/$id');

  // ===== مساحات العرض المؤجّرة =====
  Future<List<Map<String, dynamic>>> showcases({String? status}) async =>
      _list(await _api.get('/admin/showcases', query: {'status': status}));

  Future<void> approveShowcase(int id) =>
      _api.post('/admin/showcases/$id/approve');

  Future<void> rejectShowcase(int id, String reason) =>
      _api.post('/admin/showcases/$id/reject', body: {'reason': reason});

  Future<void> removeShowcase(int id, String reason) =>
      _api.post('/admin/showcases/$id/remove', body: {'reason': reason});

  Future<List<Map<String, dynamic>>> showcaseSlots() async =>
      _list(await _api.get('/admin/showcase-slots'));

  Future<void> saveShowcaseSlot(Map<String, dynamic> slot, {int? id}) =>
      id == null
          ? _api.post('/admin/showcase-slots', body: slot)
          : _api.put('/admin/showcase-slots/$id', body: slot);

  Future<void> deleteShowcaseSlot(int id) =>
      _api.delete('/admin/showcase-slots/$id');

  // ===== دعم البائعين =====
  Future<List<Map<String, dynamic>>> supportConversations() async =>
      _list(await _api.get('/admin/support'), 'conversations');

  Future<Map<String, dynamic>> supportConversation(int id) async {
    final data = await _api.get('/admin/support/$id');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<void> replySupport(int id, String body) =>
      _api.post('/admin/support/$id/message', body: {'body': body});

  Future<void> setSupportOpen(int id, bool open) =>
      _api.post('/admin/support/$id/${open ? 'reopen' : 'close'}');

  // ===== التقارير =====
  Future<Map<String, dynamic>> report(DateTime from, DateTime to) async {
    final data = await _api.get('/admin/reports', query: _range(from, to));
    return Map<String, dynamic>.from(data as Map);
  }

  Future<Uint8List> reportPdf(DateTime from, DateTime to) =>
      _api.getBytes('/admin/reports/export', query: _range(from, to));

  // ===== المحاسبة ({sellerId} = معرّف المستخدم البائع) =====
  Future<Map<String, dynamic>> accounting(DateTime from, DateTime to) async {
    final data = await _api.get('/admin/accounting', query: _range(from, to));
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<Map<String, dynamic>>> accountingSellers({String? q}) async =>
      _list(await _api.get('/admin/accounting/sellers', query: {'q': q}));

  Future<Map<String, dynamic>> sellerLedger(
      int sellerId, DateTime from, DateTime to) async {
    final data = await _api.get('/admin/accounting/sellers/$sellerId',
        query: _range(from, to));
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> adjustSeller(int sellerId,
          {required String direction,
          required double amount,
          required String reason}) =>
      _api.post('/admin/accounting/sellers/$sellerId/adjustments', body: {
        'direction': direction,
        'amount': amount,
        'reason': reason,
      });

  Future<Map<String, dynamic>> createStatement(
          int sellerId, DateTime from, DateTime to) async =>
      _item(await _api.post('/admin/accounting/sellers/$sellerId/statements',
          body: _range(from, to)));

  Future<Uint8List> statementPdf(int statementId) =>
      _api.getBytes('/admin/accounting/statements/$statementId/download');

  Future<Uint8List> sellerLedgerCsv(int sellerId, DateTime from, DateTime to) =>
      _api.getBytes('/admin/accounting/sellers/$sellerId/export',
          query: _range(from, to));

  Map<String, String> _range(DateTime from, DateTime to) => {
        'from': _date(from),
        'to': _date(to),
      };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
