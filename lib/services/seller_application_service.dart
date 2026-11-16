import 'package:image_picker/image_picker.dart';

import 'api_client.dart';

class SellerApplicationService {
  final ApiClient _api = ApiClient();

  Future<Map<String, dynamic>> getProfile() async {
    final data = await _api.get('/seller/profile');
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }

  Future<Map<String, dynamic>> submitApplication({
    required String storeName,
    String? storeDescription,
    String? commercialRegister,
    String? identityType,
    String? identityNumber,
    required XFile identityDocument,
    XFile? identityDocumentBack,
  }) async {
    final data = await _api.postMultipart(
      '/seller/application',
      fields: {
        'store_name': storeName,
        if (storeDescription != null && storeDescription.isNotEmpty)
          'store_description': storeDescription,
        if (commercialRegister != null && commercialRegister.isNotEmpty)
          'commercial_register': commercialRegister,
        if (identityType != null && identityType.isNotEmpty)
          'identity_type': identityType,
        if (identityNumber != null && identityNumber.isNotEmpty)
          'identity_number': identityNumber,
      },
      files: {
        'identity_document': identityDocument,
        if (identityDocumentBack != null)
          'identity_document_back': identityDocumentBack,
      },
    );
    return data is Map ? Map<String, dynamic>.from(data) : {};
  }
}
