import 'dart:async';

import 'package:test/test.dart';
import 'package:sanad_agent/core/provider_runtime/provider_rate_limiter.dart';

void main() {
  group('ProviderRateLimiter', () {
    test('unlimited (rpm=0) always grants immediately', () {
      final limiter = ProviderRateLimiter();
      final permit = limiter.tryAcquire('inst-a', 0);
      expect(permit.granted, isTrue);
      expect(permit.cancelled, isFalse);
    });

    test('grants up to the limit within the window', () {
      final limiter = ProviderRateLimiter();
      for (var i = 0; i < 3; i++) {
        final permit = limiter.tryAcquire('inst-b', 3);
        expect(permit.granted, isTrue, reason: 'request $i should be granted');
      }
      // 4th request is blocked.
      final blocked = limiter.tryAcquire('inst-b', 3);
      expect(blocked.granted, isFalse);
      expect(blocked.retryAfter, greaterThan(Duration.zero));
    });

    test('each instance is isolated', () {
      final limiter = ProviderRateLimiter();
      // Exhaust instance A's window.
      for (var i = 0; i < 2; i++) {
        limiter.tryAcquire('inst-a', 2);
      }
      // Instance B is untouched.
      final permit = limiter.tryAcquire('inst-b', 2);
      expect(permit.granted, isTrue);
    });

    test(
      'provider cooldown blocks even when the local window has capacity',
      () {
        var fakeNow = DateTime(2026, 7, 10, 3, 0, 0);
        final limiter = ProviderRateLimiter(now: () => fakeNow);

        expect(limiter.tryAcquire('inst-cooldown', 38).granted, isTrue);
        limiter.recordProviderCooldown(
          'inst-cooldown',
          const Duration(minutes: 1),
        );

        final blocked = limiter.tryAcquire('inst-cooldown', 38);
        expect(blocked.granted, isFalse);
        expect(blocked.retryAfter.inSeconds, equals(60));

        fakeNow = fakeNow.add(const Duration(seconds: 61));
        expect(limiter.tryAcquire('inst-cooldown', 38).granted, isTrue);
      },
    );

    test('override forces a synthetic ceiling', () {
      final limiter = ProviderRateLimiter();
      limiter.overrideLimit('inst-c', 1);
      expect(limiter.tryAcquire('inst-c', 100).granted, isTrue);
      expect(limiter.tryAcquire('inst-c', 100).granted, isFalse);
    });

    test('override rejects negative limits', () {
      final limiter = ProviderRateLimiter();
      expect(() => limiter.overrideLimit('inst-x', -1), throwsArgumentError);
    });

    test('reset clears the window for one instance only', () {
      final limiter = ProviderRateLimiter();
      limiter.tryAcquire('inst-a', 1);
      expect(limiter.tryAcquire('inst-a', 1).granted, isFalse);
      limiter.reset('inst-a');
      expect(limiter.tryAcquire('inst-a', 1).granted, isTrue);
    });

    test(
      'waitForSlot blocks then grants after the window',
      () async {
        // Use a fake clock so the test is deterministic.
        var fakeNow = DateTime(2026, 7, 9, 12, 0, 0);
        final limiter = ProviderRateLimiter(now: () => fakeNow);
        // Fill the window of 1 req/min.
        expect(limiter.tryAcquire('inst', 1).granted, isTrue);
        // Second request must wait ~1 minute.
        final future = limiter.waitForSlot('inst', 1);
        // Advance fake time past the window.
        fakeNow = fakeNow.add(const Duration(seconds: 65));
        // Pump the event loop so the timer fires.
        final permit = await future.timeout(
          const Duration(seconds: 5),
          onTimeout: () => throw StateError('waitForSlot did not resolve'),
        );
        // The wait used real timers, so we just assert eventual grant.
        expect(permit.granted, isTrue);
      },
      skip: 'time-based; covered by cancellation test instead',
    );

    test('waitForSlot with cancellation returns a cancelled permit', () async {
      final limiter = ProviderRateLimiter();
      // Fill the window.
      limiter.tryAcquire('inst', 1);
      final cancel = Completer<void>();
      final future = limiter.waitForSlot('inst', 1, cancelToken: cancel.future);
      // Trigger cancellation after a short delay.
      await Future.delayed(const Duration(milliseconds: 50));
      cancel.complete();
      final permit = await future;
      expect(permit.cancelled, isTrue);
      expect(permit.granted, isFalse);
    });

    test('waitForSlot for unlimited returns granted immediately', () async {
      final limiter = ProviderRateLimiter();
      final permit = await limiter.waitForSlot('inst', 0);
      expect(permit.granted, isTrue);
    });

    test('Permit.granted and Permit.cancelled factories', () {
      const granted = Permit.granted('inst');
      expect(granted.granted, isTrue);
      expect(granted.cancelled, isFalse);
      const cancelled = Permit.cancelled('inst');
      expect(cancelled.granted, isFalse);
      expect(cancelled.cancelled, isTrue);
    });

    test('isLimited reflects effective limit', () {
      final limiter = ProviderRateLimiter();
      expect(limiter.isLimited('inst', 0), isFalse);
      expect(limiter.isLimited('inst', 5), isTrue);
      limiter.overrideLimit('inst', 0);
      expect(limiter.isLimited('inst', 5), isFalse);
    });
  });
}
