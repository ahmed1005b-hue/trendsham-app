import '../models/return_request.dart';
import 'api_client.dart';

/// دين متجر للمنصة (بالليرة).
class StoreDebt {
  const StoreDebt({
    required this.sellerProfileId,
    required this.storeName,
    required this.debt,
    this.ownerName,
    this.phone,
    this.selfDelivery = false,
  });

  final int sellerProfileId;
  final String storeName;
  final String? ownerName;
  final String? phone;
  final double debt;
  final bool selfDelivery;

  factory StoreDebt.fromJson(Map<String, dynamic> json) => StoreDebt(
        sellerProfileId: (json['seller_profile_id'] as num).toInt(),
        storeName: json['store_name']?.toString() ?? '',
        ownerName: json['owner_name']?.toString(),
        phone: json['phone']?.toString(),
        debt: (json['debt'] as num?)?.toDouble() ?? 0,
        selfDelivery: json['self_delivery'] == true,
      );
}

class StoreDebtsPage {
  const StoreDebtsPage(this.items, this.total, this.limit);

  final List<StoreDebt> items;
  final double total;
  final double limit;
}

/// طلب إرجاع كما يراه المدير: الطلب نفسه + ما يستطيع فعله الآن + نموذج الاسترداد.
class AdminReturn {
  const AdminReturn({
    required this.request,
    this.canDecide = false,
    this.canConfirmReceived = false,
    this.canRecordRefund = false,
    this.suggestedAmount = 0,
    this.maxExtraShipping = 0,
    this.giftBalanceUsed = 0,
    this.giftBalanceRefundable = 0,
    this.methods = const [],
  });

  final ReturnRequest request;
  final bool canDecide;
  final bool canConfirmReceived;
  final bool canRecordRefund;
  final double suggestedAmount;
  final double maxExtraShipping;
  final double giftBalanceUsed;
  final double giftBalanceRefundable;

  /// طرق الاسترداد: (القيمة، الاسم)
  final List<(String, String)> methods;

  factory AdminReturn.fromJson(Map<String, dynamic> json) {
    final actions = Map<String, dynamic>.from(json['actions'] ?? {});
    final form = Map<String, dynamic>.from(json['refund_form'] ?? {});
    double n(String k) => (form[k] as num?)?.toDouble() ?? 0;
    return AdminReturn(
      request:
          ReturnRequest.fromJson(Map<String, dynamic>.from(json['data'] ?? {})),
      canDecide: actions['decide'] == true,
      canConfirmReceived: actions['confirm_received'] == true,
      canRecordRefund: actions['record_refund'] == true,
      suggestedAmount: n('suggested_amount'),
      maxExtraShipping: n('max_extra_shipping'),
      giftBalanceUsed: n('gift_balance_used'),
      giftBalanceRefundable: n('gift_balance_refundable'),
      methods: (form['methods'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ('${m['value']}', '${m['label']}'))
          .toList(),
    );
  }
}

class AdminReturnsPage {
  const AdminReturnsPage(this.items, this.escalated, this.awaitingRefund);

  final List<ReturnRequest> items;
  final int escalated;
  final int awaitingRefund;
}

/// كوبون بائع بانتظار المراجعة أو مُراجَع.
class SellerCouponReview {
  const SellerCouponReview({
    required this.id,
    required this.title,
    required this.status,
    this.statusLabel,
    this.storeName,
    this.valueLabel,
    this.audienceLabel,
    this.giftProduct,
    this.reviewNote,
    this.endsAt,
    this.issuedCount = 0,
    this.redeemedCount = 0,
  });

  final int id;
  final String title;
  final String status;
  final String? statusLabel;
  final String? storeName;
  final String? valueLabel;
  final String? audienceLabel;
  final String? giftProduct;
  final String? reviewNote;
  final DateTime? endsAt;
  final int issuedCount;
  final int redeemedCount;

  bool get isPending => status == 'pending_review';
  bool get canSuspend => status == 'active' || status == 'paused';

  factory SellerCouponReview.fromJson(Map<String, dynamic> json) =>
      SellerCouponReview(
        id: (json['id'] as num).toInt(),
        title: json['title']?.toString() ?? '',
        status: json['status']?.toString() ?? '',
        statusLabel: json['status_label']?.toString(),
        storeName: json['store_name']?.toString(),
        valueLabel: json['value_label']?.toString(),
        audienceLabel: json['audience_label']?.toString(),
        giftProduct: json['gift_product']?.toString(),
        reviewNote: json['review_note']?.toString(),
        endsAt: DateTime.tryParse('${json['ends_at'] ?? ''}'),
        issuedCount: (json['issued_count'] as num?)?.toInt() ?? 0,
        redeemedCount: (json['redeemed_count'] as num?)?.toInt() ?? 0,
      );
}

class SellerCouponsPage {
  const SellerCouponsPage(this.items, this.pendingCount, this.statuses);

  final List<SellerCouponReview> items;
  final int pendingCount;

  /// (القيمة، الاسم)
  final List<(String, String)> statuses;
}

/// ديون المتاجر، والمرتجعات، ومراجعة كوبونات البائعين للمدير (نفس صفحات الموقع).
class AdminReviewService {
  AdminReviewService({this.returnsBase = '/admin'});

  /// الموظف يقرر في المرتجعات تحت '/employee' (إرجاع المال للمدير وحده).
  AdminReviewService.employee() : this(returnsBase: '/employee');

  final ApiClient _api = ApiClient();

  /// بادئة مسارات المرتجعات: '/admin' للمدير و'/employee' للموظف.
  final String returnsBase;

  Map<String, dynamic> _map(dynamic data) =>
      Map<String, dynamic>.from(data as Map);

  // ===== ديون المتاجر =====
  Future<StoreDebtsPage> debts() async {
    final data = _map(await _api.get('/admin/accounting/debts'));
    return StoreDebtsPage(
      (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => StoreDebt.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      (data['total'] as num?)?.toDouble() ?? 0,
      (data['limit'] as num?)?.toDouble() ?? 0,
    );
  }

  Future<String> payDebt(int sellerProfileId, double amount,
      {String? note}) async {
    final data = _map(await _api.post(
        '/admin/accounting/debts/$sellerProfileId/pay',
        body: {'amount': amount, if ((note ?? '').isNotEmpty) 'note': note}));
    return data['message']?.toString() ?? '';
  }

  // ===== المرتجعات =====
  Future<AdminReturnsPage> returns({String tab = 'escalated'}) async {
    final data =
        _map(await _api.get('$returnsBase/returns', query: {'tab': tab}));
    final counts = Map<String, dynamic>.from(data['counts'] ?? {});
    return AdminReturnsPage(
      (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ReturnRequest.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      (counts['escalated'] as num?)?.toInt() ?? 0,
      (counts['awaiting_refund'] as num?)?.toInt() ?? 0,
    );
  }

  Future<AdminReturn> showReturn(int id) async =>
      AdminReturn.fromJson(_map(await _api.get('$returnsBase/returns/$id')));

  Future<AdminReturn> _returnAction(int id, String action,
          [Map<String, dynamic>? body]) async =>
      AdminReturn.fromJson(_map(
          await _api.post('$returnsBase/returns/$id/$action', body: body)));

  Future<AdminReturn> approveReturn(int id, {String? note}) =>
      _returnAction(id, 'approve', {if ((note ?? '').isNotEmpty) 'note': note});

  Future<AdminReturn> rejectReturn(int id, {required String note}) =>
      _returnAction(id, 'reject', {'note': note});

  Future<AdminReturn> confirmReceived(int id) => _returnAction(id, 'received');

  Future<AdminReturn> recordRefund(
    int id, {
    required double amount,
    required String method,
    String? reference,
    String? note,
    double? extraShipping,
  }) =>
      _returnAction(id, 'refund', {
        'amount': amount,
        'method': method,
        if ((reference ?? '').isNotEmpty) 'reference': reference,
        if ((note ?? '').isNotEmpty) 'note': note,
        if (extraShipping != null && extraShipping > 0)
          'extra_shipping': extraShipping,
      });

  // ===== كوبونات البائعين =====
  Future<SellerCouponsPage> sellerCoupons({String? status}) async {
    final data = _map(await _api.get('/admin/seller-coupons',
        query: {if (status != null) 'status': status}));
    return SellerCouponsPage(
      (data['data'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => SellerCouponReview.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      (data['pending_count'] as num?)?.toInt() ?? 0,
      (data['statuses'] as List? ?? const [])
          .whereType<Map>()
          .map((m) => ('${m['value']}', '${m['label']}'))
          .toList(),
    );
  }

  Future<String> reviewCoupon(int id, String action, {String? reason}) async {
    final data = _map(await _api.post('/admin/seller-coupons/$id/$action',
        body: {if (reason != null) 'reason': reason}));
    return data['message']?.toString() ?? '';
  }
}
