import 'package:flutter_test/flutter_test.dart';
import 'package:trendsham/config/api_config.dart';

void main() {
  group('API transport configuration', () {
    test('allows local HTTP automatically in non-release builds', () {
      expect(ApiConfig.allowInsecureHttp, isTrue);
    });

    test('accepts HTTPS regardless of the development opt-in', () {
      expect(
        ApiConfig.isTransportAllowed('https://api.example.com/api/v1'),
        isTrue,
      );
      expect(
        ApiConfig.isTransportAllowed(
          'https://api.example.com/api/v1',
          allowInsecureHttp: true,
        ),
        isTrue,
      );
    });

    test('requires explicit opt-in for HTTP', () {
      expect(
        ApiConfig.isTransportAllowed('http://api.example.com/api/v1'),
        isFalse,
      );
      expect(
        ApiConfig.isTransportAllowed(
          'http://api.example.com/api/v1',
          allowInsecureHttp: true,
        ),
        isTrue,
      );
      expect(ApiConfig.isTransportAllowed('not a URL'), isFalse);
    });
  });
}
