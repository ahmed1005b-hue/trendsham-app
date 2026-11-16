import 'package:image_picker/image_picker.dart';
import '../models/return_request.dart';
import 'api_client.dart';

/// طلبات الإرجاع للعميل (/api/v1/returns).
class ReturnService {
  final ApiClient _api = ApiClient();

  Future<ReturnsPage> list({int page = 1}) async {
    final data = await _api.get('/returns', query: {'page': page});
    return ReturnsPage.fromResponse(data, page);
  }

  Future<ReturnRequest> show(int id) async {
    final data = await _api.get('/returns/$id');
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }

  Future<List<ReturnableLine>> returnable(int orderId) async {
    final data = await _api.get('/orders/$orderId/returnable');
    final rows =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    return rows
        .whereType<Map>()
        .map((m) => ReturnableLine.fromJson(Map<String, dynamic>.from(m)))
        .toList();
  }

  /// [lines]: order_item_id => الكمية.
  Future<ReturnRequest> create(
    int orderId, {
    required Map<int, int> lines,
    required String reason,
    String? description,
    List<XFile> photos = const [],
  }) async {
    final data = await _api.postMultipart(
      '/orders/$orderId/returns',
      fields: {
        for (final e in lines.entries) 'lines[${e.key}]': '${e.value}',
        'reason': reason,
        if (description != null && description.trim().isNotEmpty)
          'description': description.trim(),
      },
      images: photos,
      imageParamName: 'photos[]',
    );
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }

  Future<ReturnRequest> withdraw(int id) async {
    final data = await _api.post('/returns/$id/withdraw');
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }

  Future<ReturnRequest> dispute(int id,
      {required String note, List<XFile> photos = const []}) async {
    final data = await _api.postMultipart(
      '/returns/$id/dispute',
      fields: {'note': note.trim()},
      images: photos,
      imageParamName: 'photos[]',
    );
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }
}
