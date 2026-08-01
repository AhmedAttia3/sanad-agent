import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:test/test.dart';

void main() {
  group('Kiro Gateway Anthropic Detailed E2E Tests', () {
    const gatewayUrl = 'http://localhost:9000';
    const apiKey = 'my-super-secret-password-123';
    const testModel = 'claude-sonnet-4.5';

    test('1. Verify system prompt integration', () async {
      final response = await http.post(
        Uri.parse('$gatewayUrl/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': testModel,
          'max_tokens': 128,
          'system':
              'You are a helpful assistant. You MUST include the custom tag KNIGHT_CONFIRMED in your greeting.',
          'messages': [
            {'role': 'user', 'content': 'Hello, say a short greeting.'},
          ],
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = body['content'] as List<dynamic>;
      final textBlock = contentList.firstWhere((c) => c['type'] == 'text');
      final text = textBlock['text'] as String;

      print('System Prompt Response: $text');
      expect(text.toUpperCase(), contains('KNIGHT_CONFIRMED'));
    });

    test('2. Verify multi-turn context preservation', () async {
      final response = await http.post(
        Uri.parse('$gatewayUrl/v1/messages'),
        headers: {
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'model': testModel,
          'max_tokens': 128,
          'messages': [
            {'role': 'user', 'content': 'My favorite animal is a blue whale.'},
            {
              'role': 'assistant',
              'content':
                  'I have noted that your favorite animal is a blue whale.',
            },
            {
              'role': 'user',
              'content':
                  'What is my favorite animal? Answer with a single word or short phrase.',
            },
          ],
        }),
      );

      expect(response.statusCode, equals(200));
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final contentList = body['content'] as List<dynamic>;
      final textBlock = contentList.firstWhere((c) => c['type'] == 'text');
      final text = textBlock['text'] as String;

      print('Multi-turn Response: $text');
      expect(text.toLowerCase(), contains('blue whale'));
    });

    test('3. Verify SSE streaming protocol compliance', () async {
      final client = http.Client();
      final request = http.Request('POST', Uri.parse('$gatewayUrl/v1/messages'))
        ..headers.addAll({
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'model': testModel,
          'max_tokens': 128,
          'messages': [
            {'role': 'user', 'content': 'Tell me a 3-word sentence.'},
          ],
          'stream': true,
        });

      final streamedResponse = await client.send(request);
      expect(streamedResponse.statusCode, equals(200));

      final lines = await streamedResponse.stream
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .toList();

      client.close();

      expect(lines, isNotEmpty);

      final events = <String>[];
      final receivedData = <Map<String, dynamic>>[];

      String? currentEvent;
      for (final line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('event:')) {
          currentEvent = trimmed.substring(6).trim();
          events.add(currentEvent);
        } else if (trimmed.startsWith('data:')) {
          final dataStr = trimmed.substring(5).trim();
          if (dataStr != '[DONE]') {
            try {
              final dataJson = jsonDecode(dataStr) as Map<String, dynamic>;
              receivedData.add(dataJson);
            } catch (e) {
              // Ignore non-json data if any
            }
          }
        }
      }

      print('Received event sequence: $events');
      expect(events, contains('message_start'));
      expect(events, contains('content_block_start'));
      expect(events, contains('content_block_delta'));
      expect(events, contains('message_stop'));

      final startEventData = receivedData.firstWhere(
        (d) => d['type'] == 'message_start',
        orElse: () => <String, dynamic>{},
      );
      expect(startEventData, isNotEmpty);
      expect(startEventData['message'], isNotNull);
      expect(startEventData['message']['model'], equals(testModel));
    });
  });
}
