import 'package:sanad_agent/engine/adapters/llm_http_exception.dart';
import 'package:test/test.dart';

void main() {
  group('LlmHttpException.resolveRetryAfter', () {
    final now = DateTime.utc(2026, 7, 10, 12, 0, 0);

    Duration? resolve({
      Map<String, String> headers = const {},
      String body = '',
    }) {
      return LlmHttpException.resolveRetryAfter(
        headers: headers,
        body: body,
        now: now,
      );
    }

    test('prefers retry-after-ms over Retry-After', () {
      final delay = resolve(
        headers: const {'retry-after-ms': '1500', 'Retry-After': '30'},
      );
      expect(delay, equals(const Duration(milliseconds: 1500)));
    });

    test('parses Retry-After seconds', () {
      final delay = resolve(headers: const {'Retry-After': '12'});
      expect(delay, equals(const Duration(seconds: 12)));
    });

    test('parses Retry-After HTTP-date', () {
      final delay = resolve(
        headers: const {'Retry-After': 'Fri, 10 Jul 2026 12:00:45 GMT'},
      );
      expect(delay, equals(const Duration(seconds: 45)));
    });

    test('parses OpenAI reset only when matching remaining is zero', () {
      final delay = resolve(
        headers: const {
          'X-RateLimit-Remaining-Requests': '0',
          'X-RateLimit-Reset-Requests': '17s',
        },
      );
      expect(delay, equals(const Duration(seconds: 17)));
    });

    test('parses Anthropic reset only when matching remaining is zero', () {
      final delay = resolve(
        headers: const {
          'Anthropic-RateLimit-Requests-Remaining': '0',
          'Anthropic-RateLimit-Requests-Reset': '2026-07-10T12:03:00Z',
        },
      );
      expect(delay, equals(const Duration(minutes: 3)));
    });

    test(
      'uses the farthest exhausted dimension when multiple resets apply',
      () {
        final delay = resolve(
          headers: const {
            'x-ratelimit-remaining-requests': '0',
            'x-ratelimit-reset-requests': '15s',
            'x-ratelimit-remaining-tokens': '0',
            'x-ratelimit-reset-tokens': '30s',
          },
        );
        expect(delay, equals(const Duration(seconds: 30)));
      },
    );

    test('ignores reset when remaining is above zero', () {
      final delay = resolve(
        headers: const {
          'x-ratelimit-remaining-requests': '1',
          'x-ratelimit-reset-requests': '15s',
        },
      );
      expect(delay, isNull);
    });

    test('parses explicit reset timestamp from body', () {
      final delay = resolve(
        body:
            'Usage limit reached for 5 hour. Your limit will reset at 2026-07-10 17:21:28',
      );
      expect(delay, equals(const Duration(hours: 5, minutes: 21, seconds: 28)));
    });

    test('treats body timestamps without timezone as UTC', () {
      final delay = resolve(
        body: 'Your limit will reset at 2026-07-10 12:05:00',
      );
      expect(delay, equals(const Duration(minutes: 5)));
    });

    test('supports absolute epoch reset headers', () {
      final delay = resolve(
        headers: const {
          'x-ratelimit-remaining-requests': '0',
          'x-ratelimit-reset-requests': '1783684830000',
        },
      );
      expect(delay, equals(const Duration(seconds: 30)));
    });

    test('ignores malformed, negative, expired, and unknown-unit hints', () {
      expect(resolve(headers: const {'retry-after-ms': '-1'}), isNull);
      expect(resolve(headers: const {'Retry-After': '-1'}), isNull);
      expect(
        resolve(
          headers: const {'Retry-After': 'Fri, 10 Jul 2026 11:59:00 GMT'},
        ),
        isNull,
      );
      expect(
        resolve(
          headers: const {
            'x-ratelimit-remaining-requests': '0',
            'x-ratelimit-reset-requests': '4d',
          },
        ),
        isNull,
      );
      expect(
        resolve(
          headers: const {
            'anthropic-ratelimit-requests-remaining': '0',
            'anthropic-ratelimit-requests-reset': 'NaN',
          },
        ),
        isNull,
      );
    });

    test('rejects invalid calendar timestamps instead of normalizing them', () {
      expect(
        resolve(body: 'Your limit will reset at 2026-13-01 00:00:00'),
        isNull,
      );
      expect(
        resolve(body: 'Your limit will reset at 2026-02-30 00:00:00'),
        isNull,
      );
      expect(
        resolve(body: 'Your limit will reset at 2026-07-10 25:00:00'),
        isNull,
      );
      expect(
        resolve(
          headers: const {
            'x-ratelimit-remaining-requests': '0',
            'x-ratelimit-reset-requests': '2026-13-01T00:00:00Z',
          },
        ),
        isNull,
      );
    });

    test('uses a single injected now even at the reset boundary', () {
      final boundaryNow = DateTime.utc(2026, 7, 10, 12, 0, 0);
      final delay = LlmHttpException.resolveRetryAfter(
        headers: const {'Retry-After': 'Fri, 10 Jul 2026 12:00:00 GMT'},
        body: '',
        now: boundaryNow,
      );
      expect(delay, isNull);

      final oneMillisecondBefore = boundaryNow.subtract(
        const Duration(milliseconds: 1),
      );
      final almostExpired = LlmHttpException.resolveRetryAfter(
        headers: const {'Retry-After': 'Fri, 10 Jul 2026 12:00:00 GMT'},
        body: '',
        now: oneMillisecondBefore,
      );
      expect(almostExpired, equals(const Duration(milliseconds: 1)));
    });
  });
}
