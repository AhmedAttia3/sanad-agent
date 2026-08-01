import 'dart:convert';
import 'package:test/test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad_agent/core/setup/setup_helpers.dart';

void main() {
  group('setup_helpers tests', () {
    test('checkNonAsciiCredential - strips non-ASCII characters', () {
      final sanitized = checkNonAsciiCredential('MY_KEY', 'ascii_only_key');
      expect(sanitized, equals('ascii_only_key'));

      // Contains Unicode smart quotes
      final dirtyKey = 'myKey\u201dValue';
      final cleaned = checkNonAsciiCredential('MY_KEY', dirtyKey);
      expect(cleaned, equals('myKeyValue'));
    });

    group('testProviderConnection', () {
      test('should return true on successful HTTP 200 connection', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/chat/completions'));
          return http.Response(jsonEncode({'id': 'chatcmpl-123'}), 200);
        });

        final result = await testProviderConnection(
          provider: 'openai',
          llmBaseUrl: 'https://api.openai.com/v1',
          llmModel: 'gpt-4o',
          llmApiKey: 'test-api-key',
          clientOverride: mockClient,
        );

        expect(result, isTrue);
      });

      test('should return false on failure HTTP 401 response', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Unauthorized', 401);
        });

        final result = await testProviderConnection(
          provider: 'openai',
          llmBaseUrl: 'https://api.openai.com/v1',
          llmModel: 'gpt-4o',
          llmApiKey: 'invalid-key',
          clientOverride: mockClient,
        );

        expect(result, isFalse);
      });

      test('should return true for Anthropic v1/messages endpoint', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/v1/messages'));
          expect(request.headers['x-api-key'], equals('claude-key'));
          return http.Response(jsonEncode({'id': 'msg-123'}), 200);
        });

        final result = await testProviderConnection(
          provider: 'anthropic',
          llmBaseUrl: 'https://api.anthropic.com',
          llmModel: 'claude-3-5-sonnet-latest',
          llmApiKey: 'claude-key',
          clientOverride: mockClient,
        );

        expect(result, isTrue);
      });

      test('should return true for Ollama server version endpoint', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/api/version'));
          return http.Response(jsonEncode({'version': '0.1.48'}), 200);
        });

        final result = await testProviderConnection(
          provider: 'ollama',
          llmBaseUrl: 'http://localhost:11434',
          llmModel: 'gemma4:e2b',
          llmApiKey: '',
          clientOverride: mockClient,
        );

        expect(result, isTrue);
      });
    });

    group('fetchModelsFromApi', () {
      test('should successfully fetch and parse Ollama local models', () async {
        final mockClient = MockClient((request) async {
          expect(request.url.path, contains('/api/tags'));
          return http.Response(
            jsonEncode({
              'models': [
                {'name': 'llama3:latest'},
                {'name': 'deepseek-r1:8b'},
              ],
            }),
            200,
          );
        });

        final models = await fetchModelsFromApi(
          provider: 'ollama',
          llmBaseUrl: 'http://localhost:11434',
          llmApiKey: '',
          clientOverride: mockClient,
        );

        expect(models, equals(['llama3:latest', 'deepseek-r1:8b']));
      });

      test(
        'should successfully fetch, parse, and sort OpenAI compatible models',
        () async {
          final mockClient = MockClient((request) async {
            expect(request.url.path, contains('/models'));
            expect(
              request.headers['Authorization'],
              equals('Bearer test-token'),
            );
            return http.Response(
              jsonEncode({
                'data': [
                  {'id': 'gpt-4o-mini'},
                  {'id': 'gpt-4o'},
                ],
              }),
              200,
            );
          });

          final models = await fetchModelsFromApi(
            provider: 'openai',
            llmBaseUrl: 'https://api.openai.com/v1',
            llmApiKey: 'test-token',
            clientOverride: mockClient,
          );

          expect(models, equals(['gpt-4o', 'gpt-4o-mini']));
        },
      );

      test('should return empty list on connection failures', () async {
        final mockClient = MockClient((request) async {
          return http.Response('Error', 500);
        });

        final models = await fetchModelsFromApi(
          provider: 'openai',
          llmBaseUrl: 'https://api.openai.com/v1',
          llmApiKey: 'test-token',
          clientOverride: mockClient,
        );

        expect(models, isEmpty);
      });
    });
  });
}
