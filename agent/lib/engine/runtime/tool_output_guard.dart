import 'dart:math' as math;

/// Provider-neutral safety boundary for model-visible tool output.
///
/// Producer-side limits should prevent wasteful buffering where possible, but
/// every result still passes through this guard so MCP, platform, plugin, and
/// future tools cannot bypass the context budget.
class ToolOutputGuard {
  static const int maxResultChars = 50000;
  static const int maxBatchChars = 100000;
  static const int _minimumBatchResultChars = 256;

  const ToolOutputGuard._();

  static String guardResult(String result, {int maxChars = maxResultChars}) {
    if (result.length <= maxChars) {
      return result;
    }
    if (maxChars <= 0) {
      return '';
    }

    var marker = _marker(result.length, result.length - maxChars);
    if (marker.length >= maxChars) {
      return marker.substring(0, maxChars);
    }

    // Recalculate after reserving marker space so the reported omission count
    // reflects the actual retained head and tail.
    final retainedChars = maxChars - marker.length;
    marker = _marker(result.length, result.length - retainedChars);
    final finalRetainedChars = math.max(0, maxChars - marker.length);
    final headChars = (finalRetainedChars * 0.4).floor();
    final tailChars = finalRetainedChars - headChars;

    final head = result.substring(0, headChars);
    final tail = tailChars == 0
        ? ''
        : result.substring(result.length - tailChars);
    return '$head$marker$tail';
  }

  /// Enforces the aggregate budget while preserving result identity and order.
  /// The largest results are reduced first, matching the strategy used by the
  /// reference runtime's per-turn budget enforcement.
  static Map<String, String> guardBatch(
    Map<String, String> results, {
    int maxChars = maxBatchChars,
  }) {
    final guarded = <String, String>{
      for (final entry in results.entries) entry.key: guardResult(entry.value),
    };
    var total = guarded.values.fold<int>(0, (sum, value) => sum + value.length);
    if (total <= maxChars || guarded.isEmpty) {
      return guarded;
    }

    final largestFirst = guarded.keys.toList(growable: false)
      ..sort(
        (left, right) =>
            guarded[right]!.length.compareTo(guarded[left]!.length),
      );
    for (final key in largestFirst) {
      if (total <= maxChars) {
        break;
      }
      final current = guarded[key]!;
      final overflow = total - maxChars;
      final target = math.max(
        _minimumBatchResultChars,
        current.length - overflow,
      );
      final replacement = guardResult(current, maxChars: target);
      guarded[key] = replacement;
      total += replacement.length - current.length;
    }

    // A very large number of tiny tool calls can make the minimum preview
    // exceed the batch budget. Apply an even final ceiling in that rare case.
    if (total > maxChars) {
      final fairShare = math.max(1, maxChars ~/ guarded.length);
      for (final key in guarded.keys) {
        guarded[key] = guardResult(guarded[key]!, maxChars: fairShare);
      }
    }
    return guarded;
  }

  static String _marker(int originalChars, int omittedChars) =>
      '\n\n... [TOOL OUTPUT TRUNCATED: omitted $omittedChars of $originalChars characters] ...\n\n';
}
