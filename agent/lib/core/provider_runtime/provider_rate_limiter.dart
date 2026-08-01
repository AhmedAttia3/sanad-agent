import 'dart:async';
import 'dart:math';

/// Per-`provider_instance_id` sliding-window rate limiter (Plan 30 §6.3).
///
/// Keeps a rolling list of request timestamps within the last minute for each
/// instance. Before invoking the LLM, the caller asks for a [Permit]. If the
/// window is full, the limiter reports how long to wait and provides a
/// cancellable future that resolves when a slot opens.
///
/// - `0` requests/minute means unlimited: [acquire] returns a granted permit
///   immediately.
/// - Each instance is isolated: a rate-limited instance never blocks a
///   different instance.
/// - Cancelling the returned future (e.g. on stop or provider change) aborts
///   the wait without leaking state.
class ProviderRateLimiter {
  /// Per-instance rolling timestamps of accepted requests.
  final Map<String, List<DateTime>> _windows = {};

  /// Per-instance provider-declared cooldowns observed from real upstream 429s.
  final Map<String, DateTime> _cooldowns = {};

  /// Optional override of the configured limit, keyed by instance id. Useful
  /// for tests and for forcing a synthetic ceiling.
  final Map<String, int> _overrides = {};

  final DateTime Function() _now;
  final Random _random;

  ProviderRateLimiter({DateTime Function()? now, Random? random})
    : _now = now ?? DateTime.now,
      _random = random ?? Random();

  /// Whether the instance is currently locally rate-limited (rpm > 0).
  bool isLimited(String providerInstanceId, int requestsPerMinute) {
    return effectiveLimit(providerInstanceId, requestsPerMinute) > 0;
  }

  /// Effective limit: explicit override wins, else the configured rpm.
  int effectiveLimit(String providerInstanceId, int requestsPerMinute) {
    final override = _overrides[providerInstanceId];
    if (override != null) return override;
    return requestsPerMinute;
  }

  /// Override the configured limit for an instance (tests / runtime ceilings).
  void overrideLimit(String providerInstanceId, int limit) {
    if (limit < 0) {
      throw ArgumentError(
        'Rate limit override must be >= 0 (0 = unlimited). Got $limit.',
      );
    }
    _overrides[providerInstanceId] = limit;
  }

  /// Clears the override for an instance (falls back to configured rpm).
  void clearOverride(String providerInstanceId) {
    _overrides.remove(providerInstanceId);
  }

  /// Attempts to acquire a permit for [providerInstanceId].
  ///
  /// Returns a [Permit] immediately when:
  /// - the configured limit is `0` (unlimited), or
  /// - there is room in the current 1-minute window.
  ///
  /// Otherwise returns a [Permit] with `granted = false` and [Permit.retryAfter]
  /// describing how long to wait. Use [waitForSlot] to block until a slot opens.
  Permit tryAcquire(String providerInstanceId, int requestsPerMinute) {
    final cooldown = _activeCooldown(providerInstanceId);
    if (cooldown != null) {
      final retryAfter = cooldown.difference(_now());
      return Permit(
        providerInstanceId: providerInstanceId,
        granted: false,
        retryAfter: retryAfter.isNegative ? Duration.zero : retryAfter,
      );
    }
    final limit = effectiveLimit(providerInstanceId, requestsPerMinute);
    if (limit <= 0) {
      return Permit.granted(providerInstanceId);
    }
    final now = _now();
    final windowStart = now.subtract(const Duration(minutes: 1));
    final window = (_windows[providerInstanceId] ?? const <DateTime>[])
        .where((t) => t.isAfter(windowStart))
        .toList();
    if (window.length < limit) {
      window.add(now);
      _windows[providerInstanceId] = window;
      return Permit.granted(providerInstanceId);
    }
    // Window is full: the oldest accepted request determines when a slot
    // opens.
    final oldest = window.reduce((a, b) => a.isBefore(b) ? a : b);
    final opensAt = oldest.add(const Duration(minutes: 1));
    final retryAfter = opensAt.difference(now);
    return Permit(
      providerInstanceId: providerInstanceId,
      granted: false,
      retryAfter: retryAfter.isNegative ? Duration.zero : retryAfter,
    );
  }

  /// Waits until a slot opens for [providerInstanceId], then records a request
  /// and returns a granted permit. The wait is cancellable: if [cancelToken]
  /// completes first, a [Permit.cancelled] is returned and no request is
  /// recorded.
  ///
  /// A small jitter (0–500 ms) is added to the wait to desynchronize multiple
  /// sessions hitting the same provider at the same instant (Plan 30 §7.2).
  Future<Permit> waitForSlot(
    String providerInstanceId,
    int requestsPerMinute, {
    Future<void>? cancelToken,
  }) async {
    final limit = effectiveLimit(providerInstanceId, requestsPerMinute);
    if (limit <= 0) {
      return Permit.granted(providerInstanceId);
    }
    while (true) {
      final permit = tryAcquire(providerInstanceId, requestsPerMinute);
      if (permit.granted) return permit;

      // Jittered wait to avoid thundering herd on the same provider.
      final jitterMs = _random.nextInt(500);
      final wait = permit.retryAfter + Duration(milliseconds: jitterMs);

      if (cancelToken == null) {
        await Future.delayed(wait);
      } else {
        // Race the delay against cancellation.
        final raceCompleter = Completer<void>();
        final timer = Timer(wait, () {
          if (!raceCompleter.isCompleted) raceCompleter.complete();
        });
        bool cancelled = false;
        cancelToken.whenComplete(() {
          cancelled = true;
          if (!raceCompleter.isCompleted) raceCompleter.complete();
        });
        try {
          await raceCompleter.future;
        } finally {
          timer.cancel();
        }
        if (cancelled) {
          return Permit.cancelled(providerInstanceId);
        }
      }
    }
  }

  /// Records a real provider-side rate limit so every session using the same
  /// provider instance waits locally before sending another request.
  void recordProviderCooldown(String providerInstanceId, Duration retryAfter) {
    final until = _now().add(retryAfter);
    final current = _activeCooldown(providerInstanceId);
    if (current == null || until.isAfter(current)) {
      _cooldowns[providerInstanceId] = until;
    }
  }

  DateTime? _activeCooldown(String providerInstanceId) {
    final until = _cooldowns[providerInstanceId];
    if (until == null) return null;
    if (!until.isAfter(_now())) {
      _cooldowns.remove(providerInstanceId);
      return null;
    }
    return until;
  }

  /// Clears all recorded timestamps (used on stop, failover, or tests).
  void reset([String? providerInstanceId]) {
    if (providerInstanceId == null) {
      _windows.clear();
      _cooldowns.clear();
    } else {
      _windows.remove(providerInstanceId);
      _cooldowns.remove(providerInstanceId);
    }
  }
}

/// Result of a rate-limit acquisition attempt.
class Permit {
  final String providerInstanceId;
  final bool granted;
  final bool cancelled;
  final Duration retryAfter;

  const Permit({
    required this.providerInstanceId,
    required this.granted,
    this.cancelled = false,
    this.retryAfter = Duration.zero,
  });

  const Permit.granted(String providerInstanceId)
    : this(providerInstanceId: providerInstanceId, granted: true);

  const Permit.cancelled(String providerInstanceId)
    : this(
        providerInstanceId: providerInstanceId,
        granted: false,
        cancelled: true,
      );
}
