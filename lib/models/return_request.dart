double _toDouble(dynamic value, [double fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString()) ?? fallback;
}

int _toInt(dynamic value, [int fallback = 0]) {
  if (value == null) return fallback;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString()) ?? fallback;
}

DateTime? _toDate(dynamic value) =>
    value == null ? null : DateTime.tryParse(value.toString());

/// أسباب الإرجاع الثابتة (المفاتيح كما يقبلها السيرفر).
const returnReasonKeys = [
  'damaged',
  'not_as_described',
  'wrong_size_or_color',
  'changed_mind',
  'other',
];

/// سطر قابل للإرجاع من طلب (GET /orders/{id}/returnable).
class ReturnableLine {
  final int orderItemId;

  /// المتجر الذي يخصه السطر: طلب الإرجاع الواحد يخص متجراً واحداً.
  final int? vendorId;
  final String? storeName;
  final String productName;
  final String? variantLabel;
  final double unitPrice;
  final int quantity;
  final int returnableQuantity;
  final DateTime? windowEndsAt;

  const ReturnableLine({
    required this.orderItemId,
    this.vendorId,
    this.storeName,
    required this.productName,
    this.variantLabel,
    required this.unitPrice,
    required this.quantity,
    required this.returnableQuantity,
    this.windowEndsAt,
  });

  factory ReturnableLine.fromJson(Map<String, dynamic> json) => ReturnableLine(
        orderItemId: _toInt(json['order_item_id']),
        vendorId: json['vendor_id'] == null ? null : _toInt(json['vendor_id']),
        storeName: json['store_name']?.toString(),
        productName: (json['product_name'] ?? '').toString(),
        variantLabel: json['variant_label']?.toString(),
        unitPrice: _toDouble(json['unit_price']),
        quantity: _toInt(json['quantity']),
        returnableQuantity: _toInt(json['returnable_quantity']),
        windowEndsAt: _toDate(json['window_ends_at']),
      );
}

class ReturnItem {
  final int id;
  final int orderItemId;
  final String productName;
  final String? variantLabel;
  final int quantity;
  final double refundAmount;

  const ReturnItem({
    required this.id,
    required this.orderItemId,
    required this.productName,
    this.variantLabel,
    required this.quantity,
    required this.refundAmount,
  });

  factory ReturnItem.fromJson(Map<String, dynamic> json) => ReturnItem(
        id: _toInt(json['id']),
        orderItemId: _toInt(json['order_item_id']),
        productName: (json['product_name'] ?? '').toString(),
        variantLabel: json['variant_label']?.toString(),
        quantity: _toInt(json['quantity']),
        refundAmount: _toDouble(json['refund_amount']),
      );
}

class ReturnEvent {
  final int id;
  final String type;
  final String label;
  final String? actorRole;
  final String? note;
  final List<String> photos;
  final DateTime? createdAt;

  const ReturnEvent({
    required this.id,
    required this.type,
    required this.label,
    this.actorRole,
    this.note,
    this.photos = const [],
    this.createdAt,
  });

  factory ReturnEvent.fromJson(Map<String, dynamic> json) => ReturnEvent(
        id: _toInt(json['id']),
        type: (json['type'] ?? '').toString(),
        label: (json['label'] ?? json['type'] ?? '').toString(),
        actorRole: json['actor_role']?.toString(),
        note: json['note']?.toString(),
        photos: json['photos'] is List
            ? (json['photos'] as List).map((p) => p.toString()).toList()
            : const [],
        createdAt: _toDate(json['created_at']),
      );
}

class ReturnRefund {
  final double amount;
  final String? method;

  /// تسمية الطريقة مترجمة من السيرفر (حوالة بنكية، نقداً، أخرى).
  final String? methodLabel;
  final String? reference;

  const ReturnRefund(
      {required this.amount, this.method, this.methodLabel, this.reference});

  factory ReturnRefund.fromJson(Map<String, dynamic> json) => ReturnRefund(
        amount: _toDouble(json['amount']),
        method: json['method']?.toString(),
        methodLabel: json['method_label']?.toString(),
        reference: json['reference']?.toString(),
      );

  /// ما يُعرض للمستخدم: التسمية، أو المفتاح إن غابت (سيرفر أقدم).
  String? get displayMethod => methodLabel ?? method;
}

class ReturnRequest {
  final int id;
  final String number;
  final String status;
  final String statusLabel;
  final String reason;
  final String reasonLabel;
  final String? description;
  final String? decisionNote;
  final int orderId;
  final String? orderNumber;
  final String? storeName;
  final String? customerName;
  /// إجمالي المسترد ويشمل أجرة التوصيل إن رُدّت ([shippingRefund] جزء منه لا إضافة عليه).
  final double refundAmount;
  final double shippingRefund;
  final DateTime? respondBy;
  final DateTime? disputeBy;
  final DateTime? shipBackBy;
  final DateTime? receivedAt;
  final DateTime? closedAt;
  final DateTime? createdAt;
  final List<ReturnItem> items;
  final List<ReturnEvent> events;
  final ReturnRefund? refund;

  /// أزرار مسموحة من السيرفر فقط؛ لا نعيد حساب قواعد الحالة في التطبيق.
  final bool canWithdraw;
  final bool canDispute;
  final bool canApprove;
  final bool canReject;
  final bool canConfirmReceived;

  const ReturnRequest({
    required this.id,
    required this.number,
    required this.status,
    required this.statusLabel,
    required this.reason,
    required this.reasonLabel,
    this.description,
    this.decisionNote,
    required this.orderId,
    this.orderNumber,
    this.storeName,
    this.customerName,
    required this.refundAmount,
    required this.shippingRefund,
    this.respondBy,
    this.disputeBy,
    this.shipBackBy,
    this.receivedAt,
    this.closedAt,
    this.createdAt,
    this.items = const [],
    this.events = const [],
    this.refund,
    this.canWithdraw = false,
    this.canDispute = false,
    this.canApprove = false,
    this.canReject = false,
    this.canConfirmReceived = false,
  });

  factory ReturnRequest.fromJson(Map<String, dynamic> json) {
    List<T> list<T>(String key, T Function(Map<String, dynamic>) build) =>
        json[key] is List
            ? (json[key] as List)
                .whereType<Map>()
                .map((m) => build(Map<String, dynamic>.from(m)))
                .toList()
            : <T>[];

    final actions = json['actions'] is Map ? json['actions'] as Map : const {};

    return ReturnRequest(
      id: _toInt(json['id']),
      number: (json['number'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      statusLabel: (json['status_label'] ?? json['status'] ?? '').toString(),
      reason: (json['reason'] ?? '').toString(),
      reasonLabel: (json['reason_label'] ?? json['reason'] ?? '').toString(),
      description: json['description']?.toString(),
      decisionNote: json['decision_note']?.toString(),
      orderId: _toInt(json['order_id']),
      orderNumber: json['order_number']?.toString(),
      storeName: json['store_name']?.toString(),
      customerName: json['customer_name']?.toString(),
      refundAmount: _toDouble(json['refund_amount']),
      shippingRefund: _toDouble(json['shipping_refund']),
      respondBy: _toDate(json['respond_by']),
      disputeBy: _toDate(json['dispute_by']),
      shipBackBy: _toDate(json['ship_back_by']),
      receivedAt: _toDate(json['received_at']),
      closedAt: _toDate(json['closed_at']),
      createdAt: _toDate(json['created_at']),
      items: list('items', ReturnItem.fromJson),
      events: list('events', ReturnEvent.fromJson),
      refund: json['refund'] is Map
          ? ReturnRefund.fromJson(Map<String, dynamic>.from(json['refund']))
          : null,
      canWithdraw: actions['can_withdraw'] == true,
      canDispute: actions['can_dispute'] == true,
      canApprove: actions['can_approve'] == true,
      canReject: actions['can_reject'] == true,
      canConfirmReceived: actions['can_confirm_received'] == true,
    );
  }
}

/// صفحة من قائمة طلبات الإرجاع.
class ReturnsPage {
  final List<ReturnRequest> items;
  final int currentPage;
  final int lastPage;
  final int total;

  const ReturnsPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
    this.total = 0,
  });

  /// من استجابة Laravel المقسّمة (data + meta).
  factory ReturnsPage.fromResponse(dynamic data, int requestedPage) {
    final rows =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    final meta = data is Map && data['meta'] is Map ? data['meta'] as Map : {};
    return ReturnsPage(
      items: rows
          .whereType<Map>()
          .map((m) => ReturnRequest.fromJson(Map<String, dynamic>.from(m)))
          .toList(),
      currentPage:
          int.tryParse('${meta['current_page'] ?? requestedPage}') ??
              requestedPage,
      lastPage:
          int.tryParse('${meta['last_page'] ?? requestedPage}') ?? requestedPage,
      total: int.tryParse('${meta['total'] ?? 0}') ?? 0,
    );
  }

  bool get hasMore => currentPage < lastPage;
}
