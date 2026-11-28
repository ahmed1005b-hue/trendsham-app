import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../models/category.dart';
import '../models/product.dart';
import '../models/seller_profile.dart';
import '../models/coupon_story.dart';
import '../models/order.dart';
import 'api_client.dart';

class AdminService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> dashboard() async {
    final data = await _api.get('/admin/dashboard');
    return {
      'sellers_count': data['sellers_count'] ?? 0,
      'customers_count': data['customers_count'] ?? 0,
      'pending_sellers_count': data['pending_sellers_count'] ?? 0,
      'identity_review_count': data['identity_review_count'] ?? 0,
      'pending_products_count': data['pending_products_count'] ?? 0,
      'pending_withdrawals_count': data['pending_withdrawals_count'] ?? 0,
      'total_sales': double.tryParse(data['total_sales'].toString()) ?? 0,
      'total_commission':
          double.tryParse(data['total_commission'].toString()) ?? 0,
    };
  }

  /// تحليلات المنصة الشاملة (نفس أرقام صفحة الويب)؛ المبالغ بالليرة.
  Future<Map<String, dynamic>> analytics({int days = 30}) async {
    final data = await _api.get('/admin/analytics', query: {'days': '$days'});
    return Map<String, dynamic>.from(data as Map);
  }

  Future<List<SellerProfileModel>> sellers({String status = 'pending'}) async {
    final data = await _api.get('/admin/sellers', query: {'status': status});
    return (data['data'] as List)
        .map((s) => SellerProfileModel.fromJson(s))
        .toList();
  }

  Future<List<SellerProfileModel>> approvedSellers() async {
    const pageSize = 20;
    final sellers = <SellerProfileModel>[];
    var page = 1;
    var lastPage = 1;

    do {
      final data = await _api.get('/admin/sellers', query: {
        'status': 'approved',
        'page': page,
      });
      sellers.addAll((data['data'] as List)
          .map((seller) => SellerProfileModel.fromJson(seller)));
      lastPage = (data['meta']?['last_page'] as num?)?.toInt() ??
          ((data['data'] as List).length < pageSize ? page : page + 1);
      page++;
    } while (page <= lastPage);

    return sellers;
  }

  Future<List<Map<String, dynamic>>> pendingEmployees() async {
    final data = await _api.get('/admin/employees');
    return (data['data'] as List)
        .map((item) => Map<String, dynamic>.from(item as Map))
        .toList();
  }

  /// سجل نشاط الفريق (نفس صفحة الموقع): التصفية بالشخص ونوع العمل والتاريخ.
  Future<StaffActivityPage> staffActivity(
      {int? userId,
      String? group,
      String? from,
      String? to,
      int page = 1}) async {
    final data = await _api.get('/admin/staff-activity', query: {
      if (userId != null) 'user_id': '$userId',
      if (group != null) 'group': group,
      if (from != null) 'from': from,
      if (to != null) 'to': to,
      'page': '$page',
    });
    final map = Map<String, dynamic>.from(data as Map);
    List<Map<String, dynamic>> list(String key) =>
        (map[key] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
    final meta = Map<String, dynamic>.from(map['meta'] ?? const {});
    return StaffActivityPage(
      list('data').map(StaffActivityEntry.fromJson).toList(),
      list('staff')
          .map((m) => (
                id: (m['id'] as num).toInt(),
                name: '${m['name'] ?? ''}',
                isAdmin: m['role'] == 'admin',
              ))
          .toList(),
      list('groups').map((m) => ('${m['value']}', '${m['label']}')).toList(),
      (meta['current_page'] as num?)?.toInt() ?? 1,
      (meta['last_page'] as num?)?.toInt() ?? 1,
    );
  }

  /// الموظفون المعتمدون وأقسام كل واحد.
  Future<EmployeeTeam> employeeTeam() async {
    final data = Map<String, dynamic>.from(
        await _api.get('/admin/employees/team') as Map);
    List<Map<String, dynamic>> list(String key) =>
        (data[key] as List? ?? const [])
            .whereType<Map>()
            .map((m) => Map<String, dynamic>.from(m))
            .toList();
    return EmployeeTeam(
      list('data')
          .map((m) => (
                id: (m['id'] as num).toInt(),
                name: '${m['name'] ?? ''}',
                sections: (m['sections'] as List? ?? const [])
                    .map((s) => '$s')
                    .toList(),
              ))
          .toList(),
      list('sections').map((m) => ('${m['value']}', '${m['label']}')).toList(),
    );
  }

  /// يحفظ أقسام الموظف ويعيد رسالة الخادم.
  Future<String> updateEmployeeSections(int id, List<String> sections) async {
    final data = await _api
        .put('/admin/employees/$id/permissions', body: {'sections': sections});
    return '${(data as Map)['message'] ?? ''}';
  }

  Future<void> approveEmployee(int id) async {
    await _api.post('/admin/employees/$id/approve');
  }

  Future<void> rejectEmployee(int id) async {
    await _api.post('/admin/employees/$id/reject');
  }

  Future<void> updateSellerCommission(int sellerId, int? commissionRate) async {
    await _api.put('/admin/sellers/$sellerId/commission', body: {
      'commission_rate': commissionRate,
    });
  }

  Future<Map<String, dynamic>> sellerWallet(int sellerId,
      {int page = 1}) async {
    final rawData = await _api
        .get('/admin/sellers/$sellerId/wallet', query: {'page': page});
    final data = Map<String, dynamic>.from(rawData as Map);
    final transactions = data['transactions'];
    final transactionData =
        transactions is Map ? Map<String, dynamic>.from(transactions) : {};
    final transactionRows = transactionData['data'] as List? ?? const [];
    final meta = transactionData['meta'] is Map
        ? Map<String, dynamic>.from(transactionData['meta'] as Map)
        : <String, dynamic>{};

    return {
      'balance': double.tryParse((data['balance'] ?? 0).toString()) ?? 0,
      'pending_withdrawals':
          double.tryParse((data['pending_withdrawals'] ?? 0).toString()) ?? 0,
      'transactions': transactionRows
          .whereType<Map>()
          .map((row) =>
              WalletTransactionModel.fromJson(Map<String, dynamic>.from(row)))
          .toList(),
      'current_page': (meta['current_page'] as num?)?.toInt() ?? page,
      'last_page': (meta['last_page'] as num?)?.toInt() ?? page,
    };
  }

  Future<void> approveSeller(int id) async {
    await _api.post('/admin/sellers/$id/approve');
  }

  Future<Uint8List> identityDocument(int id, {String side = 'front'}) async {
    final path = side == 'back'
        ? '/admin/sellers/$id/identity-document?side=back'
        : '/admin/sellers/$id/identity-document';
    return _api.getBytes(path);
  }

  Future<void> rejectSeller(int id, String reason) async {
    await _api.post('/admin/sellers/$id/reject', body: {'reason': reason});
  }

  /// إيقاف المتجر: يختفي عن الزوار، وتبقى محفظته وطلباته وسجلاته
  Future<void> suspendSeller(int id, String reason) async {
    await _api.post('/admin/sellers/$id/suspend', body: {'reason': reason});
  }

  Future<void> unsuspendSeller(int id) async {
    await _api.post('/admin/sellers/$id/unsuspend');
  }

  Future<void> deleteSeller(int id) async {
    await _api.delete('/admin/sellers/$id');
  }

  Future<List<Product>> pendingProducts({
    String filter = 'pending',
    bool employeeMode = false,
  }) async {
    final data = await _api.get(
        employeeMode ? '/employee/products' : '/admin/products',
        query: {'filter': filter});
    return (data['data'] as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<void> approveProduct(int id, {bool employeeMode = false}) async {
    final prefix = employeeMode ? '/employee' : '/admin';
    await _api.post('$prefix/products/$id/approve');
  }

  Future<void> rejectProduct(int id, String note,
      {bool employeeMode = false}) async {
    final prefix = employeeMode ? '/employee' : '/admin';
    await _api
        .post('$prefix/products/$id/reject', body: {'rejection_note': note});
  }

  Future<void> updateEmployeeProduct({
    required int id,
    required String name,
    required String description,
    required int categoryId,
    required double price,
    required int stockQuantity,
  }) async {
    await _api.put('/employee/products/$id', body: {
      'name': name,
      'description': description,
      'category_id': categoryId,
      'price': price,
      'stock_quantity': stockQuantity,
    });
  }

  Future<void> archiveEmployeeProduct(int id) async {
    await _api.post('/employee/products/$id/archive');
  }

  Future<List<dynamic>> withdrawals({String status = 'pending'}) async {
    final data =
        await _api.get('/admin/withdrawals', query: {'status': status});
    return data['data'] as List;
  }

  Future<void> approveWithdrawal(int id) async {
    await _api.post('/admin/withdrawals/$id/approve');
  }

  Future<void> rejectWithdrawal(int id, String note) async {
    await _api
        .post('/admin/withdrawals/$id/reject', body: {'admin_note': note});
  }

  /// تأكيد وصول الحوالة: رقم الحوالة إلزامي، وصورة/PDF الإيصال اختيارية.
  Future<void> markWithdrawalPaid(int id, String reference,
      {XFile? receipt}) async {
    await _api.postMultipart(
      '/admin/withdrawals/$id/paid',
      fields: {'transfer_reference': reference},
      files: receipt != null ? {'receipt': receipt} : null,
    );
  }

  /// فشل التحويل: يُعاد المبلغ لمحفظة البائع.
  Future<void> markWithdrawalFailed(int id, String reason) async {
    await _api.post('/admin/withdrawals/$id/failed',
        body: {'failure_reason': reason});
  }

  /// إعادة إرسال الحوالة عبر API البنك (عند تفعيل التحويل التلقائي).
  Future<void> sendWithdrawal(int id) async {
    await _api.post('/admin/withdrawals/$id/send');
  }

  Future<bool> togglePayoutMethodVerified(int paymentMethodId) async {
    final data =
        await _api.post('/admin/payout-methods/$paymentMethodId/verify');
    return data is Map && data['is_verified'] == true;
  }

  Future<List<Category>> categories() async {
    final data = await _api.get('/admin/categories');
    return (data['data'] as List).map((c) => Category.fromJson(c)).toList();
  }

  Future<void> createCategory(String name, {int? parentId}) async {
    await _api
        .post('/admin/categories', body: {'name': name, 'parent_id': parentId});
  }

  Future<void> updateCategory(int id,
      {required String name, int? parentId}) async {
    await _api.put('/admin/categories/$id',
        body: {'name': name, 'parent_id': parentId});
  }

  Future<void> deleteCategory(int id) async {
    await _api.delete('/admin/categories/$id');
  }

  // ===== الكوبونات =====
  // ===== الستوري =====
  Future<List<StoryModel>> stories() async {
    final data = await _api.get('/admin/stories');
    return (data['data'] as List).map((s) => StoryModel.fromJson(s)).toList();
  }

  Future<void> createStory(
      {required XFile image,
      String? caption,
      String? linkUrl,
      required int durationHours}) async {
    await _api.postMultipart(
      '/admin/stories',
      fields: {
        if (caption != null && caption.isNotEmpty) 'caption': caption,
        if (linkUrl != null && linkUrl.isNotEmpty) 'link_url': linkUrl,
        'duration_hours': durationHours.toString(),
      },
      images: [image],
      imageParamName: 'image',
    );
  }

  Future<void> deleteStory(int id) async {
    await _api.delete('/admin/stories/$id');
  }

  // ===== إعدادات المنصة =====
  /// كل إعدادات المنصة الرقمية (العمولة، الستوري، أجور الشحن، الديون، مهل المرتجعات)
  Future<Map<String, dynamic>> settings() async {
    final data = await _api.get('/admin/settings');
    return Map<String, dynamic>.from(data as Map);
  }

  Future<void> updateSettings(Map<String, num> values) async {
    await _api.put('/admin/settings', body: values);
  }

  // ===== إدارة الطلبات =====
  /// [view]: active | new | late | archived (للمدير). [query]: رقم الطلب أو اسم الزبون أو هاتفه.
  Future<List<Order>> orders(
      {bool employeeMode = false,
      String? query,
      String? view,
      String? status}) async {
    final data = await _api
        .get(employeeMode ? '/employee/orders' : '/admin/orders', query: {
      if (query != null && query.isNotEmpty) 'q': query,
      if (view != null && view != 'active') 'view': view,
      if (status != null && status.isNotEmpty) 'status': status,
    });
    return (data['data'] as List).map((o) => Order.fromJson(o)).toList();
  }

  /// الزبون رفض استلام طرد: يُلغى الطرد وتعود كمياته، وأجرة شحنه دين عليه.
  Future<({Order order, String? message})> markRefused(
      int orderId, int shipmentId,
      {bool employeeMode = false}) async {
    final prefix = employeeMode ? '/employee' : '/admin';
    final data =
        await _api.post('$prefix/orders/$orderId/parcels/$shipmentId/refused');
    return (
      order: Order.fromJson(data['data'] ?? data),
      message: data is Map ? data['message']?.toString() : null,
    );
  }

  Future<Order> getOrder(int id, {bool employeeMode = false}) async {
    final prefix = employeeMode ? '/employee' : '/admin';
    final data = await _api.get('$prefix/orders/$id');
    return Order.fromJson(data['data'] ?? data);
  }

  Future<Order> updateOrderStatus(int id, String status,
      {String? trackingNumber,
      String? reason,
      bool employeeMode = false}) async {
    final prefix = employeeMode ? '/employee' : '/admin';
    final data = await _api.put('$prefix/orders/$id/status', body: {
      'status': status,
      // سبب الإلغاء إلزامي في الخادم ويصل للزبون والبائع
      if (reason != null && reason.isNotEmpty) 'reason': reason,
      // الموظف لا يرى حقل رقم التتبع، والخادم لا يقبله منه
      if (!employeeMode && trackingNumber != null && trackingNumber.isNotEmpty)
        'tracking_number': trackingNumber,
    });
    return Order.fromJson(data['data'] ?? data);
  }

  /// إلغاء طلب مدفوع مع تسجيل رد المال للزبون (المدير فقط).
  /// [method]: card | bank_transfer | cash
  Future<Order> cancelWithRefund(int id,
      {required String reason, required String method, String? note}) async {
    final data = await _api.post('/admin/orders/$id/cancel-refund', body: {
      'reason': reason,
      'refund_method': method,
      if (note != null && note.isNotEmpty) 'refund_note': note,
    });
    return Order.fromJson(data['data'] ?? data);
  }

  /// شغل اليوم للموظف: نفس أرقام صفحته الرئيسية في الموقع.
  Future<Map<String, int>> employeeDashboard() async {
    final data = await _api.get('/employee/dashboard');
    final counts = Map<String, dynamic>.from(data['data'] ?? const {});
    return counts
        .map((key, value) => MapEntry(key, (value as num?)?.toInt() ?? 0));
  }

  Future<void> archiveEmployeeOrder(int id) async {
    await _api.post('/employee/orders/$id/archive');
  }
}

/// سطر في سجل نشاط الفريق.
class StaffActivityEntry {
  const StaffActivityEntry({
    required this.id,
    required this.actorName,
    required this.isAdmin,
    required this.action,
    required this.description,
    this.createdAt,
  });

  factory StaffActivityEntry.fromJson(Map<String, dynamic> json) =>
      StaffActivityEntry(
        id: (json['id'] as num).toInt(),
        actorName: '${json['actor_name'] ?? ''}',
        isAdmin: json['actor_role'] == 'admin',
        action: '${json['action'] ?? ''}',
        description: '${json['description'] ?? ''}',
        createdAt: DateTime.tryParse('${json['created_at'] ?? ''}')?.toLocal(),
      );

  final int id;
  final String actorName;
  final bool isAdmin;
  final String action;
  final String description;
  final DateTime? createdAt;
}

class StaffActivityPage {
  const StaffActivityPage(
      this.entries, this.staff, this.groups, this.currentPage, this.lastPage);

  final List<StaffActivityEntry> entries;
  final List<({int id, String name, bool isAdmin})> staff;
  final List<(String, String)> groups;
  final int currentPage;
  final int lastPage;
}

/// الفريق المعتمد وأقسام لوحة الموظف المتاحة.
class EmployeeTeam {
  const EmployeeTeam(this.members, this.sections);

  final List<({int id, String name, List<String> sections})> members;
  final List<(String, String)> sections;
}
