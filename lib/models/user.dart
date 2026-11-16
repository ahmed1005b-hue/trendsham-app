import '../config/api_config.dart';
import 'user_address.dart';

class SellerProfileSummary {
  final int? id;
  final String? storeName;
  final String? status;
  final String? statusLabel;
  final String? rejectionReason;
  final bool hasIdentityDocument;
  final bool hasIdentityDocumentBack;
  final bool isIdentityVerified;
  final bool identityReviewPending;
  final String? identityType;
  final DateTime? identityVerifiedAt;
  final DateTime? identityDocumentSubmittedAt;

  const SellerProfileSummary({
    this.id,
    this.storeName,
    this.status,
    this.statusLabel,
    this.rejectionReason,
    this.hasIdentityDocument = false,
    this.hasIdentityDocumentBack = false,
    this.isIdentityVerified = false,
    this.identityReviewPending = false,
    this.identityType,
    this.identityVerifiedAt,
    this.identityDocumentSubmittedAt,
  });

  bool get isApproved => status == 'approved';
  bool get isPending => status == 'pending';
  bool get isRejected => status == 'rejected';

  factory SellerProfileSummary.fromJson(Map<String, dynamic> json) {
    return SellerProfileSummary(
      id: (json['id'] as num?)?.toInt(),
      storeName: json['store_name']?.toString(),
      status: json['status']?.toString(),
      statusLabel: json['status_label']?.toString(),
      rejectionReason: json['rejection_reason']?.toString(),
      hasIdentityDocument: json['has_identity_document'] == true,
      hasIdentityDocumentBack: json['has_identity_document_back'] == true,
      isIdentityVerified: json['is_identity_verified'] == true,
      identityReviewPending: json['identity_review_pending'] == true,
      identityType: json['identity_type']?.toString(),
      identityVerifiedAt: DateTime.tryParse(json['identity_verified_at']?.toString() ?? ''),
      identityDocumentSubmittedAt:
          DateTime.tryParse(json['identity_document_submitted_at']?.toString() ?? ''),
    );
  }
}

class AppUser {
  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String phone;
  final String? email;
  final String? address;
  final String? countryCode;
  final String? nationalNumber;
  final String? birthDate;
  final String? city;
  final String? gender;
  final String? avatar;
  final String role;
  final SellerProfileSummary? sellerProfile;

  /// رقم الهاتف موثّق فعلاً (phone_verified_at في السيرفر).
  final bool phoneVerified;

  /// عدد عناوين الشحن المحفوظة والعنوان المعتمد منها.
  final int addressesCount;
  final UserAddress? defaultAddress;

  AppUser({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.phone,
    this.email,
    this.address,
    this.countryCode,
    this.nationalNumber,
    this.birthDate,
    this.city,
    this.gender,
    this.avatar,
    required this.role,
    this.sellerProfile,
    this.phoneVerified = false,
    this.addressesCount = 0,
    this.defaultAddress,
  });

  /// شارة "موثّق": هاتف موثّق، أو بائع وُثّقت هويته.
  bool get isVerified =>
      phoneVerified || (sellerProfile?.isIdentityVerified ?? false);

  String? get avatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    final uri = Uri.tryParse(avatar!);
    if (uri != null && uri.hasAuthority) {
      if (uri.host == 'localhost' || uri.host == '127.0.0.1') {
        return '${ApiConfig.storageBaseUrl}${uri.path}';
      }
      return avatar;
    }
    final path = avatar!.startsWith('/') ? avatar! : '/storage/$avatar';
    return '${ApiConfig.storageBaseUrl}$path';
  }

  factory AppUser.fromJson(Map<String, dynamic> json) {
    final rawRole = json['role'];
    if (rawRole is! String || rawRole.trim().isEmpty) {
      throw const FormatException('User response is missing a valid role.');
    }
    return AppUser(
      id: (json['id'] as num).toInt(),
      name: json['name']?.toString() ?? '',
      firstName: json['first_name']?.toString() ?? '',
      lastName: json['last_name']?.toString() ?? '',
      phone: json['phone']?.toString() ?? '',
      email: json['email']?.toString(),
      address: json['address']?.toString(),
      countryCode: json['country_code']?.toString(),
      nationalNumber: json['national_number']?.toString(),
      birthDate: json['birth_date']?.toString(),
      city: json['city']?.toString(),
      gender: json['gender'] is String ? json['gender']?.toString() : null,
      avatar:
          json['avatar']?.toString() ?? json['avatar_url']?.toString() ?? json['profile_photo_path']?.toString(),
      role: rawRole.trim().toLowerCase(),
      sellerProfile: json['seller_profile'] is Map
          ? SellerProfileSummary.fromJson(Map<String, dynamic>.from(json['seller_profile'] as Map))
          : null,
      phoneVerified: json['phone_verified'] == true,
      addressesCount: (json['addresses_count'] as num?)?.toInt() ?? 0,
      defaultAddress: json['default_address'] is Map
          ? UserAddress.fromJson(Map<String, dynamic>.from(json['default_address'] as Map))
          : null,
    );
  }
}
