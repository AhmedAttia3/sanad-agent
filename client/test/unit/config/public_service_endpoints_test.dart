import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/core/config/public_service_endpoints.dart';

void main() {
  test('resolves public endpoints from the selected environment', () {
    expect(
      PublicServiceEndpoints.backendFor('dev'),
      'https://dev.api.sanad.eaststarai.com',
    );
    expect(
      PublicServiceEndpoints.portalFor('dev'),
      'https://dev.portal.sanad.eaststarai.com',
    );
    expect(
      PublicServiceEndpoints.backendFor('prod'),
      'https://api.sanad.eaststarai.com',
    );
    expect(
      PublicServiceEndpoints.portalFor('prod'),
      'https://portal.sanad.eaststarai.com',
    );
    expect(
      PublicServiceEndpoints.backendFor('local'),
      'http://127.0.0.1:8001',
    );
    expect(
      PublicServiceEndpoints.portalFor('local'),
      'http://127.0.0.1:8083',
    );
  });
}
