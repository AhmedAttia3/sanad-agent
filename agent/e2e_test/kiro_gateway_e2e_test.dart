import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Kiro Gateway E2E Tests', () {
    const gatewayUrl = 'http://localhost:9000';
    const apiKey = 'my-super-secret-password-123';
    const testModel = 'claude-sonnet-4.5';

    test('1. Verify /v1/models endpoint returns models successfully', () async {
      final response = await http.get(
        Uri.parse('$gatewayUrl/v1/models'),
        headers: {'Authorization': 'Bearer $apiKey'},
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('data'));

      final models = body['data'] as List<dynamic>;
      expect(models, isNotEmpty);

      final modelIds = models.map((m) => m['id'] as String).toList();
      print('Available models: $modelIds');
      expect(modelIds, contains(testModel));
    });

    test('2. Verify OpenAI-compatible chat completion works', () async {
      final response = await http.post(
        Uri.parse('$gatewayUrl/v1/chat/completions'),
        headers: {
          'Authorization': 'Bearer $apiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': testModel,
          'messages': [
            {
              'role': 'user',
              'content': 'Respond with exactly the word: "SUCCESS"',
            },
          ],
          'stream': false,
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('choices'));

      final choices = body['choices'] as List<dynamic>;
      expect(choices, isNotEmpty);

      final content = choices[0]['message']['content'] as String;
      print('OpenAI Response content: $content');
      expect(content.toUpperCase(), contains('SUCCESS'));
    });

    test('3. Verify Anthropic-compatible messages completion works', () async {
      final response = await http.post(
        Uri.parse('$gatewayUrl/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': testModel,
          'max_tokens': 1024,
          'messages': [
            {
              'role': 'user',
              'content': 'Respond with exactly the word: "SUCCESS"',
            },
          ],
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      expect(body, contains('content'));

      final contentList = body['content'] as List<dynamic>;
      expect(contentList, isNotEmpty);

      // Find the text block (ignoring thinking block if any)
      final textBlock = contentList.firstWhere(
        (c) => c['type'] == 'text',
        orElse: () => null,
      );
      expect(textBlock, isNotNull);

      final content = textBlock['text'] as String;
      print('Anthropic Response content: $content');
      expect(content.toUpperCase(), contains('SUCCESS'));
    });
  });
}
