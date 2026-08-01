import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sanad_agent/capabilities/runtime/web_search/web_fetch_service.dart';
import 'package:test/test.dart';

void main() {
  group('WebFetchService Tests', () {
    test('fetches multiple URLs in parallel successfully', () async {
      final mockClient = MockClient((request) async {
        final urlStr = request.url.toString();
        if (urlStr.contains('page1')) {
          return http.Response(
            '<html><head><title>Page 1</title></head><body><h1>Content 1</h1></body></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        } else if (urlStr.contains('page2')) {
          return http.Response(
            '<html><head><title>Page 2</title></head><body><h1>Content 2</h1></body></html>',
            200,
            headers: {'content-type': 'text/html'},
          );
        }
        return http.Response('Not Found', 404);
      });

      final fetchService = WebFetchService(client: mockClient);

      // Use 1.1.1.1 host to ensure fast local IP resolution in unit tests
      final results = await fetchService.fetch([
        'https://1.1.1.1/page1',
        'https://1.1.1.1/page2',
        'https://1.1.1.1/page3',
      ]);

      expect(results.length, equals(3));

      // Page 1 details
      expect(results[0].code, equals(200));
      expect(results[0].url, equals('https://1.1.1.1/page1'));
      expect(results[0].result, contains('Page 1'));
      expect(results[0].result, contains('Content 1'));

      // Page 2 details
      expect(results[1].code, equals(200));
      expect(results[1].url, equals('https://1.1.1.1/page2'));
      expect(results[1].result, contains('Page 2'));
      expect(results[1].result, contains('Content 2'));

      // Page 3 details
      expect(results[2].code, equals(404));
      expect(results[2].url, equals('https://1.1.1.1/page3'));
    });

    test('imposes a limit of maximum 5 URLs per call', () async {
      final mockClient = MockClient((request) async {
        return http.Response('ok', 200);
      });

      final fetchService = WebFetchService(client: mockClient);
      final results = await fetchService.fetch([
        'https://1.1.1.1/1',
        'https://1.1.1.1/2',
        'https://1.1.1.1/3',
        'https://1.1.1.1/4',
        'https://1.1.1.1/5',
        'https://1.1.1.1/6',
      ]);

      // Assert only 5 requests were made
      expect(results.length, equals(5));
      expect(results[0].url, equals('https://1.1.1.1/1'));
      expect(results[4].url, equals('https://1.1.1.1/5'));
    });

    test('blocks unsafe URLs via UrlSafetyValidator', () async {
      final mockClient = MockClient((request) async {
        return http.Response('ok', 200);
      });

      final fetchService = WebFetchService(client: mockClient);
      final results = await fetchService.fetch([
        'http://127.0.0.1:8000/api',
        'https://1.1.1.1/safe',
      ]);

      expect(results.length, equals(2));
      // First one is loopback, so blocked
      expect(results[0].code, equals(403));
      expect(results[0].codeText, equals('Forbidden'));
      expect(results[0].result, contains('unsafe/private address'));

      // Second one is public, so allowed
      expect(results[1].code, equals(200));
      expect(results[1].url, equals('https://1.1.1.1/safe'));
    });
  });
}
