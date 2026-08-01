import 'package:sanad_agent/capabilities/models/tool_schema.dart';
import 'package:sanad_agent/core/models/agent_response.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/capabilities.dart';

import 'llm_adapter.dart';
import 'llm_request_options.dart';

/// Raised when the runtime cannot resolve a ready provider instance for the
/// current request. The caller can surface the message to the client without
/// crashing daemon startup or dependency resolution.
class MissingProviderConfigurationException implements Exception {
  final String message;

  const MissingProviderConfigurationException(this.message);

  @override
  String toString() => message;
}

/// Safe fallback adapter returned when no provider route can be resolved.
///
/// This keeps DI/runtime startup alive and converts "missing provider"
/// conditions into ordinary request errors once the caller actually tries to
/// use the LLM.
class MissingProviderAdapter implements LLMAdapter {
  final String message;

  const MissingProviderAdapter({required this.message});

  Never _throw() {
    throw MissingProviderConfigurationException(message);
  }

  @override
  Future<AgentResponse> generateResponse(
    List<Message> history, {
    List<ToolSchema>? tools,
    String? modelOverride,
    LLMRequestOptions options = const LLMRequestOptions(),
  }) async {
    _throw();
  }

  @override
  Stream<AgentResponse> generateStream(
    List<Message> history, {
    List<ToolSchema>? tools,
    String? modelOverride,
    LLMRequestOptions options = const LLMRequestOptions(),
  }) async* {
    _throw();
  }

  @override
  Future<List<ModelOption>> getAvailableModels() async {
    _throw();
  }

  @override
  Future<int> getContextLimit([String? modelOverride]) async {
    _throw();
  }
}
