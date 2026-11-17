class SellerProfileModel {
  final int id;
  final String storeName;
  final String? storeDescription;
  final String? storeLogo;
  final String? storeBanner;
  final String? storeContactPhone;
  final String? storeWhatsapp;
  final String? storeInstagram;
  final String? businessHours;
  final Map<String, dynamic>? businessHoursSchedule;
  final String? shippingPolicy;

  /// مركز كرم الذي يسلّم فيه البائع طروده، وهل يستلمها المندوب من المتجر
  final int? dropoffCenterId;
  final bool courierPickup;
  final String? returnPolicy;
  final String? commercialRegister;
  final String? identityType;
  final String? identityNumber;
  final String status;
  final String? statusLabelApi;
  final String? rejectionReason;

  /// سبب إيقاف المتجر من الإدارة (عند status = suspended)
  final String? suspensionReason;

  bool get isSuspended => status == 'suspended';
  final bool hasIdentityDocument;
  final bool hasIdentityDocumentBack;
  final bool isIdentityVerified;
  final bool identityReviewPending;
  final DateTime? identityDocumentSubmittedAt;
  final DateTime? identityVerifiedAt;
  final int commissionRate;
  final int? commissionRateOverride;
  final String? ownerName;
  final String? ownerPhone;
  final String? ownerEmail;

  SellerProfileModel({
    required this.id,
    required this.storeName,
    this.storeDescription,
    this.storeLogo,
    this.storeBanner,
    this.storeContactPhone,
    this.storeWhatsapp,
    this.storeInstagram,
    this.businessHours,
    this.businessHoursSchedule,
    this.shippingPolicy,
    this.dropoffCenterId,
    this.courierPickup = false,
    this.returnPolicy,
    this.commercialRegister,
    this.identityType,
    this.identityNumber,
    required this.status,
    this.statusLabelApi,
    this.rejectionReason,
    this.suspensionReason,
    this.hasIdentityDocument = false,
    this.hasIdentityDocumentBack = false,
    this.isIdentityVerified = false,
    this.identityReviewPending = false,
    this.identityDocumentSubmittedAt,
    this.identityVerifiedAt,
    required this.commissionRate,
    this.commissionRateOverride,
    this.ownerName,
    this.ownerPhone,
    this.ownerEmail,
  });

  static const Map<String, String> statusLabels = {
    'pending': 'بانتظار المراجعة',
    'approved': 'معتمد',
    'rejected': 'مرفوض',
  };

  String get statusLabel => statusLabelApi ?? statusLabels[status] ?? status;
  bool get needsIdentityVerification =>
      status == 'approved' && !isIdentityVerified;

  factory SellerProfileModel.fromJson(Map<String, dynamic> json) {
    return SellerProfileModel(
      id: (json['id'] as num).toInt(),
      storeName: json['store_name']?.toString() ?? '',
      storeDescription: json['store_description']?.toString(),
      storeLogo: json['store_logo']?.toString(),
      storeBanner: json['store_banner']?.toString(),
      storeContactPhone: json['store_contact_phone']?.toString(),
      storeWhatsapp: json['store_whatsapp']?.toString(),
      storeInstagram: json['store_instagram']?.toString(),
      businessHours: json['business_hours']?.toString(),
      businessHoursSchedule: json['business_hours_schedule'] is Map
          ? Map<String, dynamic>.from(json['business_hours_schedule'] as Map)
          : null,
      shippingPolicy: json['shipping_policy']?.toString(),
      dropoffCenterId: int.tryParse(json['dropoff_center_id']?.toString() ?? ''),
      courierPickup: json['courier_pickup'] == true,
      returnPolicy: json['return_policy']?.toString(),
      commercialRegister: json['commercial_register']?.toString(),
      identityType: json['identity_type']?.toString(),
      identityNumber: json['identity_number']?.toString() ??
          json['identity_number_masked']?.toString(),
      status: json['status']?.toString() ?? 'pending',
      statusLabelApi: json['status_label']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      suspensionReason: json['suspension_reason']?.toString(),
      hasIdentityDocument: json['has_identity_document'] == true,
      hasIdentityDocumentBack: json['has_identity_document_back'] == true,
      isIdentityVerified: json['is_identity_verified'] == true,
      identityReviewPending: json['identity_review_pending'] == true,
      identityDocumentSubmittedAt: DateTime.tryParse(
          json['identity_document_submitted_at']?.toString() ?? ''),
      identityVerifiedAt:
          DateTime.tryParse(json['identity_verified_at']?.toString() ?? ''),
      commissionRate: (json['commission_rate'] as num?)?.toInt() ??
          (double.tryParse((json['commission_rate'] ?? 0).toString())
                  ?.toInt() ??
              0),
      commissionRateOverride:
          (json['commission_rate_override'] as num?)?.toInt(),
      ownerName: json['owner_name']?.toString(),
      ownerPhone: json['owner_phone']?.toString(),
      ownerEmail: json['owner_email']?.toString(),
    );
  }
}

class WalletTransactionModel {
  final int id;
  final String type;
  final String reason;
  final double amount;
  final double balanceAfter;
  final String? note;
  final DateTime? createdAt;

  WalletTransactionModel({
    required this.id,
    required this.type,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    this.note,
    this.createdAt,
  });

  static const Map<String, String> reasonLabels = {
    'order_earning': 'أرباح طلب',
    'withdrawal': 'سحب',
    'adjustment': 'تعديل يدوي',
    'story_fee': 'رسم ستوري',
  };

  String get reasonLabel => reasonLabels[reason] ?? reason;

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: (json['id'] as num?)?.toInt() ?? 0,
      type: json['type']?.toString() ?? 'credit',
      reason: json['reason']?.toString() ?? '',
      amount: double.tryParse((json['amount'] ?? 0).toString()) ?? 0,
      balanceAfter: double.tryParse(
              (json['balance_after'] ?? json['balance_after_transaction'] ?? 0)
                  .toString()) ??
          0,
      note: json['note']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
    );
  }
}
