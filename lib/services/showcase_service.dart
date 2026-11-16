import '../widgets/showcase_section.dart';
import 'api_client.dart';

/// مساحات العرض المؤجّرة على الشاشة الرئيسية (Showcases).
class ShowcaseService {
  final ApiClient _api = ApiClient();

  Future<List<ShowcaseData>> homeShowcases() async {
    final data = await _api.get('/home/showcases', withAuth: false);
    final list =
        data is Map && data['data'] is List ? data['data'] as List : const [];
    return list
        .map((e) => ShowcaseData.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// type: impression | click. الإحصاءات غير حرجة، لذا تُتجاهل أخطاؤها.
  Future<void> track(int showcaseId, String type) async {
    try {
      await _api.post('/showcases/track', withAuth: false, body: {
        'events': [
          {'id': showcaseId, 'type': type},
        ],
      });
    } catch (_) {}
  }
}
