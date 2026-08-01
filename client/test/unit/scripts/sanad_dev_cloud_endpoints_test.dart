import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../../scripts/sanad_dev/cloud_endpoints.dart';

void main() {
  test('production profile maps to public production services', () async {
    final temp = await Directory.systemTemp.createTemp('sanad-cloud-config');
    addTearDown(() => temp.delete(recursive: true));
    final config = File('${temp.path}/prod.json')
      ..writeAsStringSync('{"ENVIRONMENT":"prod"}');

    expect(readSanadCloudEndpoints(config).toAgentEnvironment(), {
      'GATEWAY_URL': 'https://api.sanad.eaststarai.com',
      'PORTAL_URL': 'https://portal.sanad.eaststarai.com',
    });
  });

  test('maps explicit development profile to internal services', () async {
    final temp = await Directory.systemTemp.createTemp('sanad-cloud-config');
    addTearDown(() => temp.delete(recursive: true));
    final config = File('${temp.path}/dev.json')..writeAsStringSync('''{"ENVIRONMENT":"dev"}''');

    expect(readSanadCloudEndpoints(config).toAgentEnvironment(), {
      'GATEWAY_URL': 'https://dev.api.sanad.eaststarai.com',
      'PORTAL_URL': 'https://dev.portal.sanad.eaststarai.com',
    });
  });

  test('allows explicit internal endpoint overrides', () async {
    final temp = await Directory.systemTemp.createTemp('sanad-cloud-config');
    addTearDown(() => temp.delete(recursive: true));
    final config = File('${temp.path}/dev.json')
      ..writeAsStringSync('''
{
  "ENVIRONMENT": "dev",
  "BACKEND_URL": "https://backend.internal.example",
  "PORTAL_URL": "https://portal.internal.example"
}
''');

    expect(readSanadCloudEndpoints(config).toAgentEnvironment(), {
      'GATEWAY_URL': 'https://backend.internal.example',
      'PORTAL_URL': 'https://portal.internal.example',
    });
  });

  test('rejects a profile without an environment', () async {
    final temp = await Directory.systemTemp.createTemp('sanad-cloud-config');
    addTearDown(() => temp.delete(recursive: true));
    final config = File('${temp.path}/dev.json')..writeAsStringSync('{}');

    expect(() => readSanadCloudEndpoints(config), throwsFormatException);
  });
}
