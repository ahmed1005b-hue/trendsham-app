import '../models/return_request.dart';
import 'api_client.dart';

/// طلبات الإرجاع لمتجر البائع (/api/v1/seller/returns).
class SellerReturnService {
  final ApiClient _api = ApiClient();

  Future<ReturnsPage> list({String? status, int page = 1}) async {
    final data = await _api.get('/seller/returns', query: {
      'page': page,
      if (status != null) 'status': status,
    });
    return ReturnsPage.fromResponse(data, page);
  }

  /// عدد الطلبات بانتظار رد البائع (إجمالي الترقيم).
  Future<int> requestedCount() async =>
      (await list(status: 'requested')).total;

  Future<ReturnRequest> show(int id) async {
    final data = await _api.get('/seller/returns/$id');
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }

  Future<ReturnRequest> approve(int id, {String? note}) => _act(
      '/seller/returns/$id/approve',
      note != null && note.trim().isNotEmpty ? {'note': note.trim()} : null);

  Future<ReturnRequest> reject(int id, {required String note}) =>
      _act('/seller/returns/$id/reject', {'note': note.trim()});

  Future<ReturnRequest> confirmReceived(int id) =>
      _act('/seller/returns/$id/received', null);

  Future<ReturnRequest> _act(String path, Map<String, dynamic>? body) async {
    final data = await _api.post(path, body: body);
    return ReturnRequest.fromJson(Map<String, dynamic>.from(data['data']));
  }
}
