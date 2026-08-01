import 'llm_http_exception.dart';

/// Signals that an adapter-owned replay fragment was rejected by its issuer.
///
/// The runner may remove only [dataKeysToClear] from matching persisted state
/// and retry once. The original HTTP failure remains available for the normal
/// runtime recovery classifier when that bounded fallback is unavailable.
class ProviderStateRejectedException implements Exception {
  final LlmHttpException httpFailure;
  final String namespace;
  final String? issuer;
  final Set<String> dataKeysToClear;

  const ProviderStateRejectedException({
    required this.httpFailure,
    required this.namespace,
    required this.issuer,
    required this.dataKeysToClear,
  });

  @override
  String toString() => httpFailure.toString();
}
