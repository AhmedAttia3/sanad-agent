import 'provider_protocol_constants.dart';

/// Normalizes model identifiers to the instance-local form used by Plan 29.
///
/// Provider instances already carry the routing identity (UUID + template), so
/// transport payloads and persisted selections should not repeat the provider
/// name as a prefix. Google's OpenAI-compatible layer also returns ids under
/// `models/...`; that transport path fragment is not part of the logical model
/// id shown to users or stored as the instance default.
class ProviderModelId {
  ProviderModelId._();

  static String normalize({
    required String templateId,
    required String protocol,
    required String rawModelId,
  }) {
    var modelId = rawModelId.trim();
    if (modelId.isEmpty) {
      return modelId;
    }

    final providerPrefix = '$templateId/';
    if (templateId.isNotEmpty && modelId.startsWith(providerPrefix)) {
      modelId = modelId.substring(providerPrefix.length);
    }

    if (modelId.startsWith('models/')) {
      modelId = modelId.substring('models/'.length);
    }

    if (protocol == ProviderProtocol.anthropicCompatible &&
        modelId.startsWith('anthropic/')) {
      modelId = modelId.substring('anthropic/'.length);
    }

    return modelId;
  }
}
