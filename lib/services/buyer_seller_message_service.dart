import 'api_client.dart';

class BuyerSellerMessageService {
  final ApiClient _api = ApiClient();

  Future<List<Map<String, dynamic>>> conversations() async {
    final response = await _api.get('/conversations');
    final data = response['data'];
    if (data is! List) {
      throw const FormatException('قائمة المحادثات غير صالحة.');
    }
    return data.whereType<Map>().map(Map<String, dynamic>.from).toList();
  }

  Future<Map<String, dynamic>> conversation(int id) async {
    final response = await _api.get('/conversations/$id');
    final data = response['data'];
    if (data is! Map) throw const FormatException('المحادثة غير صالحة.');
    return Map<String, dynamic>.from(data);
  }

  Future<void> send(int id, String body) async {
    await _api.post('/conversations/$id/messages', body: {'body': body});
  }
}
