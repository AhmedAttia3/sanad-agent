import 'package:sanad_agent/interfaces/models/agent_turn_request.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';

/// Resolves the request identifier carried by either turn request shape.
String? requestIdForEvent(GatewayEvent event) {
  final turnRequestId = event.turnRequest?.requestId;
  if (turnRequestId != null && turnRequestId.isNotEmpty) {
    return turnRequestId;
  }

  final payload = event.metadata['payload'];
  if (payload is Map) {
    final requestId = payload['request_id']?.toString();
    if (requestId != null && requestId.isNotEmpty) {
      return requestId;
    }
  }

  return event.runId;
}

/// Applies a provider/model route without retaining orchestrator state.
AgentTurnRequest overrideTurnRoute(
  AgentTurnRequest request, {
  String? providerInstanceId,
  String? modelId,
  String? Function(String providerInstanceId)? defaultModelForProvider,
}) {
  if ((providerInstanceId == null || providerInstanceId.isEmpty) &&
      (modelId == null || modelId.isEmpty)) {
    return request;
  }

  final providerChanged =
      providerInstanceId != null &&
      providerInstanceId.isNotEmpty &&
      providerInstanceId != request.effectiveProviderInstanceId;

  String? resolvedModel = modelId;
  if (providerChanged && (modelId == null || modelId.isEmpty)) {
    resolvedModel = defaultModelForProvider?.call(providerInstanceId);
  } else if (modelId == null || modelId.isEmpty) {
    resolvedModel = request.model;
  }

  return request.copyWith(
    providerInstanceId: providerInstanceId,
    providerId: providerInstanceId,
    model: resolvedModel,
  );
}
