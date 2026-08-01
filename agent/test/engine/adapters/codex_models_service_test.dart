import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad_agent/engine/adapters/codex_models_service.dart';
import 'package:test/test.dart';

void main() {
  group('CodexModelsService', () {
    test(
      'uses the Codex endpoint and parses visible models by priority',
      () async {
        late http.Request captured;
        final client = MockClient((request) async {
          captured = request;
          return http.Response(
            jsonEncode({
              'models': [
                {
                  'slug': 'codex-beta',
                  'display_name': 'Codex Beta',
                  'visibility': 'list',
                  'priority': 2,
                },
                {
                  'slug': 'codex-alpha',
                  'visibility': 'visible',
                  'priority': 1,
                  'supported_in_api': false,
                  'context_window': 128000,
                },
                {'slug': 'codex-hidden', 'visibility': 'hide', 'priority': 0},
                {'slug': 'codex-alpha', 'visibility': 'list', 'priority': 10},
              ],
            }),
            200,
          );
        });
        final service = CodexModelsService(clientVersion: '1.2.3');

        final models = await service.fetch(
          client: client,
          baseUrl: 'https://chatgpt.com/backend-api/codex/',
          accessToken: 'access-token',
        );

        expect(
          captured.url.toString(),
          'https://chatgpt.com/backend-api/codex/models?client_version=1.2.3',
        );
        expect(captured.headers['Authorization'], 'Bearer access-token');
        expect(models.map((model) => model.value), [
          'codex-alpha',
          'codex-beta',
        ]);
        expect(models.first.label, 'Codex Alpha');
        expect(models.first.contextWindow, 128000);
        expect(models.first.supportsReasoning, isTrue);
      },
    );

    test('adds Hermes forward-compatible models without duplicates', () async {
      final service = CodexModelsService(clientVersion: '1.2.3');
      final models = await service.fetch(
        client: MockClient(
          (_) async => http.Response(
            jsonEncode({
              'models': [
                {'slug': 'gpt-5.5', 'visibility': 'list', 'priority': 1},
                {'slug': 'gpt-5.6-sol', 'visibility': 'list', 'priority': 2},
              ],
            }),
            200,
          ),
        ),
        baseUrl: 'https://chatgpt.com/backend-api/codex',
        accessToken: 'access-token',
      );

      expect(models.map((model) => model.value), [
        'gpt-5.5',
        'gpt-5.6-sol',
        'gpt-5.6-sol-pro',
        'gpt-5.6-terra',
        'gpt-5.6-terra-pro',
        'gpt-5.6-luna',
        'gpt-5.6-luna-pro',
      ]);
    });

    test('rejects unsuccessful or malformed catalogs', () async {
      final service = CodexModelsService(clientVersion: '1.2.3');

      await expectLater(
        service.fetch(
          client: MockClient((_) async => http.Response('{}', 401)),
          baseUrl: 'https://chatgpt.com/backend-api/codex',
          accessToken: 'expired',
        ),
        throwsA(isA<CodexModelsException>()),
      );
      await expectLater(
        service.fetch(
          client: MockClient(
            (_) async => http.Response(jsonEncode({'data': []}), 200),
          ),
          baseUrl: 'https://chatgpt.com/backend-api/codex',
          accessToken: 'access-token',
        ),
        throwsA(isA<CodexModelsException>()),
      );
    });
  });
}
