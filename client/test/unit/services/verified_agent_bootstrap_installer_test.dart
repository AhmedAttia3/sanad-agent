import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad_client/features/devices/data/daemon/verified_agent_bootstrap_installer.dart';
import 'package:sanad_release_contract/release_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory temporaryDirectory;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'sanad-bootstrap-test-',
    );
  });

  tearDown(() async {
    if (temporaryDirectory.existsSync()) {
      await temporaryDirectory.delete(recursive: true);
    }
  });

  test('installs exactly the verified manifest artifact', () async {
    final bytes = utf8.encode('verified-agent');
    final artifactFile = File('${temporaryDirectory.path}/artifact')..writeAsBytesSync(bytes);
    final manifest = _manifest(
      size: bytes.length,
      digest: await sha256OfFile(artifactFile),
    );
    final target = '${temporaryDirectory.path}/bin/sanad';
    final installer = VerifiedAgentBootstrapInstaller(
      targetPath: target,
      operatingSystem: 'linux',
      architecture: 'x64',
      client: MockClient((request) async {
        if (request.url.path.endsWith('release-manifest.json')) {
          return http.Response(jsonEncode(manifest), 200);
        }
        return http.Response.bytes(bytes, 200);
      }),
    );

    expect(await installer.install(), isTrue);
    expect(File(target).readAsBytesSync(), bytes);
  });

  test('keeps the existing executable when verification fails', () async {
    final target = File('${temporaryDirectory.path}/sanad')..writeAsStringSync('existing');
    final manifest = _manifest(
      size: 3,
      digest: List.filled(64, '0').join(),
    );
    final installer = VerifiedAgentBootstrapInstaller(
      targetPath: target.path,
      operatingSystem: 'linux',
      architecture: 'x64',
      client: MockClient((request) async {
        if (request.url.path.endsWith('release-manifest.json')) {
          return http.Response(jsonEncode(manifest), 200);
        }
        return http.Response.bytes([1, 2, 3], 200);
      }),
    );

    expect(await installer.install(), isFalse);
    expect(target.readAsStringSync(), 'existing');
  });
}

Map<String, dynamic> _manifest({
  required int size,
  required String digest,
}) => {
  'schema_version': 1,
  'version': '1.1.0',
  'build_number': 2,
  'tag': 'v1.1.0',
  'commit': '1234567890abcdef',
  'channel': 'stable',
  'repository': 'EastStarAI/sanad-agent',
  'artifacts': [
    {
      'component': 'agent',
      'platform': 'linux',
      'architecture': 'x64',
      'format': 'executable',
      'filename': 'sanad-agent-1.1.0-linux-x64',
      'url': 'https://github.com/EastStarAI/sanad-agent/releases/download/v1.1.0/sanad-agent-1.1.0-linux-x64',
      'sha256': digest,
      'size': size,
      'public': true,
      'signature_type': 'github-attestation',
    },
  ],
};
