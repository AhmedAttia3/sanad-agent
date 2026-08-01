import '../adapters/llm_adapter.dart';

/// Immutable identity of the exact provider route used by a completed request.
///
/// [adapter] is the provider adapter that performed the network request, with
/// turn-scoped rate-limit/recovery decorators removed so a background job does
/// not inherit a completed turn's cancellation or runtime-notice lifecycle.
class LLMRouteSnapshot {
  final LLMAdapter adapter;
  final String? providerInstanceId;
  final String? modelOverride;

  const LLMRouteSnapshot({
    required this.adapter,
    required this.providerInstanceId,
    required this.modelOverride,
  });
}
