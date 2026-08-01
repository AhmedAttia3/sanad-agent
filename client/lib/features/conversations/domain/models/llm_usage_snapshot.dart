/// Latest provider-reported usage for one LLM invocation.
class LlmUsageSnapshot {
  final int? inputTokens;
  final int? outputTokens;
  final int? totalTokens;
  final int? cachedTokens;
  final int? reasoningTokens;
  final int? contextWindowTokens;
  final String? modelId;
  final String? providerInstanceId;
  final String? modelStepId;
  final DateTime? observedAt;

  const LlmUsageSnapshot({
    this.inputTokens,
    this.outputTokens,
    this.totalTokens,
    this.cachedTokens,
    this.reasoningTokens,
    this.contextWindowTokens,
    this.modelId,
    this.providerInstanceId,
    this.modelStepId,
    this.observedAt,
  });

  factory LlmUsageSnapshot.fromJson(Map<String, dynamic> json) {
    int? integer(String key) {
      final value = json[key];
      return value is num && value >= 0 ? value.toInt() : null;
    }

    return LlmUsageSnapshot(
      inputTokens: integer('input_tokens'),
      outputTokens: integer('output_tokens'),
      totalTokens: integer('total_tokens'),
      cachedTokens: integer('cached_tokens'),
      reasoningTokens: integer('reasoning_tokens'),
      contextWindowTokens: integer('context_window_tokens'),
      modelId: _text(json['model_id']),
      providerInstanceId: _text(json['provider_instance_id']),
      modelStepId: _text(json['model_step_id']),
      observedAt: DateTime.tryParse(json['observed_at']?.toString() ?? ''),
    );
  }

  double? get usageFraction {
    final input = inputTokens;
    final window = contextWindowTokens;
    if (input == null || window == null || window <= 0) return null;
    return (input / window).clamp(0, 1).toDouble();
  }

  static String? _text(dynamic value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }
}
