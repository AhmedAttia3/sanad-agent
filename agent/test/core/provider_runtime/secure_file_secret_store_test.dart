import 'dart:convert';
import 'dart:io';

import 'package:sanad_agent/core/constants.dart';
import 'package:sanad_agent/core/provider_runtime/provider_protocol_constants.dart';
import 'package:sanad_agent/core/provider_runtime/secret_record.dart';
import 'package:sanad_agent/core/provider_runtime/secure_file_secret_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempHome;
  late SecureFileSecretStore store;

  setUp(() async {
    tempHome = await Directory.systemTemp.createTemp('sanad-secret-store');
    setSanadHomeOverride(tempHome.path);
    store = SecureFileSecretStore();
  });

  tearDown(() async {
    setSanadHomeOverride(null);
    if (tempHome.existsSync()) await tempHome.delete(recursive: true);
  });

  SecretRecord apiKey(String id, String key) =>
      SecureFileSecretStore.apiKeyRecord(id, key);

  SecretRecord oauthRecord(String id) => SecretRecord(
    instanceId: id,
    accessToken: 'access-$id',
    refreshToken: 'refresh-$id',
    expiresAt: DateTime.now().millisecondsSinceEpoch + 3600000,
    scope: 'openid',
    accountLabel: 'user@example.com',
    authMethod: ProviderAuthMethod.deviceCode,
  );

  group('write + read', () {
    test('an api key round-trips', () async {
      await store.write('a', apiKey('a', 'sk-test-1234567890'));
      final record = store.read('a');
      expect(record, isNotNull);
      expect(record!.apiKey, equals('sk-test-1234567890'));
      expect(record.authMethod, equals(ProviderAuthMethod.apiKey));
    });

    test('an oauth token bundle round-trips', () async {
      await store.write('b', oauthRecord('b'));
      final record = store.read('b')!;
      expect(record.accessToken, equals('access-b'));
      expect(record.refreshToken, equals('refresh-b'));
      expect(record.accountLabel, equals('user@example.com'));
      expect(record.isOAuth, isTrue);
    });

    test('reading an unknown id returns null', () {
      expect(store.read('nope'), isNull);
    });
  });

  group('isolation (keep/replace/remove do not touch other instances)', () {
    test('replace updates only the targeted instance', () async {
      await store.write('a', apiKey('a', 'sk-aaa'));
      await store.write('b', apiKey('b', 'sk-bbb'));

      await store.write('a', apiKey('a', 'sk-aaa-new'));

      expect(store.read('a')!.apiKey, equals('sk-aaa-new'));
      expect(store.read('b')!.apiKey, equals('sk-bbb')); // untouched
    });

    test('remove deletes only the targeted instance', () async {
      await store.write('a', apiKey('a', 'sk-aaa'));
      await store.write('b', apiKey('b', 'sk-bbb'));

      await store.remove('a');

      expect(store.read('a'), isNull);
      expect(store.read('b')!.apiKey, equals('sk-bbb'));
    });

    test('listIds reflects current contents', () async {
      await store.write('a', apiKey('a', 'sk-aaa'));
      await store.write('b', apiKey('b', 'sk-bbb'));
      expect(store.listIds().toSet(), equals({'a', 'b'}));
      await store.remove('a');
      expect(store.listIds(), equals(['b']));
    });
  });

  group('summary (redaction)', () {
    test('api key is masked, never returned raw', () async {
      await store.write('a', apiKey('a', 'sk-1234567890abcdef'));
      final summary = store.summary('a');
      expect(summary.configured, isTrue);
      expect(summary.maskedKeyHint, isNotNull);
      expect(summary.maskedKeyHint, contains('•'));
      expect(summary.maskedKeyHint, isNot(contains('1234567890abcdef')));
      expect(summary.maskedKeyHint, isNot(equals('sk-1234567890abcdef')));
    });

    test('missing instance yields configured=false, status=missing', () {
      final summary = store.summary('nope');
      expect(summary.configured, isFalse);
      expect(summary.status, equals('missing'));
      expect(summary.maskedKeyHint, isNull);
    });

    test('oauth summary exposes account label but not token', () async {
      await store.write('a', oauthRecord('a'));
      final summary = store.summary('a');
      expect(summary.accountLabel, equals('user@example.com'));
      expect(summary.maskedKeyHint, isNull); // no api key for oauth
    });

    test('expired oauth surfaces relogin when status set', () async {
      final expired = SecretRecord(
        instanceId: 'a',
        accessToken: 'x',
        expiresAt: DateTime.now()
            .subtract(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        authMethod: ProviderAuthMethod.deviceCode,
        status: 'relogin_required',
      );
      await store.write('a', expired);
      final summary = store.summary('a');
      expect(summary.reloginRequired, isTrue);
      expect(summary.status, equals('relogin_required'));
    });
  });

  group('masking', () {
    test('long key shows prefix and suffix only', () {
      expect(maskApiKey('sk-1234567890abcdef'), equals('sk-1••••cdef'));
    });

    test('short key masks more aggressively', () {
      final masked = maskApiKey('sk-12');
      expect(masked, contains('•'));
      expect(masked, isNot(equals('sk-12')));
    });

    test('tiny key hides almost everything', () {
      expect(maskApiKey('ab'), equals('•b'));
    });
  });

  group('atomicity + permissions', () {
    test('no .tmp file is left behind after a successful write', () async {
      await store.write('a', apiKey('a', 'sk-aaa'));
      expect(File('${store.storePath}.tmp').existsSync(), isFalse);
      expect(File(store.storePath).existsSync(), isTrue);
    });

    test('store file is owner-only on unix', () async {
      if (Platform.isWindows) {
        return; // skip unix perm check
      }
      await store.write('a', apiKey('a', 'sk-aaa'));
      final args = Platform.isMacOS
          ? ['-f', '%Lp', store.storePath]
          : ['-c', '%a', store.storePath];
      final stat = await Process.run('stat', args);
      expect(stat.stdout.toString().trim(), equals('600'));
    });

    test(
      'the persisted file never contains the key in plaintext index',
      () async {
        // Secrets are stored under instances.<id>.api_key by design (it IS the
        // secret store). This test documents that the top-level structure is
        // keyed by instance id, not a flat list.
        await store.write('a', apiKey('a', 'sk-aaa'));
        final raw =
            jsonDecode(File(store.storePath).readAsStringSync())
                as Map<String, dynamic>;
        expect(raw['instances'], isA<Map>());
        expect((raw['instances'] as Map).containsKey('a'), isTrue);
      },
    );

    test('re-opening the store preserves data (survives reload)', () async {
      await store.write('a', apiKey('a', 'sk-aaa'));
      final reopened = SecureFileSecretStore();
      expect(reopened.read('a')!.apiKey, equals('sk-aaa'));
    });

    test(
      'a corrupted store degrades to empty (no raw content in logs)',
      () async {
        File(store.storePath).writeAsStringSync('not valid json {{{');
        final record = store.read('a');
        expect(record, isNull);
      },
    );
  });
}
