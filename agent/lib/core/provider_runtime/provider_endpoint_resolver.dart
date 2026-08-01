import 'provider_protocol_constants.dart';

/// Centralized service to normalize URLs and resolve endpoints for OpenAI and
/// Anthropic protocols (Plan 29 §10.1).
class ProviderEndpointResolver {
  ProviderEndpointResolver._();

  /// Cleans and normalizes the base URL by trimming spaces and stripping
  /// trailing slashes.
  static String normalizeBaseUrl(String baseUrl) {
    var url = baseUrl.trim();
    while (url.endsWith('/')) {
      url = url.substring(0, url.length - 1);
    }
    return url;
  }

  /// Resolves the models endpoint for the given base URL and protocol.
  /// - OpenAI-compatible: appends `/models` to the normalized base.
  /// - Anthropic-compatible: appends `/models` if ending in `/v1`, else `/v1/models`.
  static Uri resolveModelsEndpoint(String baseUrl, String protocol) {
    final normalized = normalizeBaseUrl(baseUrl);
    if (protocol == ProviderProtocol.anthropicCompatible) {
      if (normalized.endsWith('/v1')) {
        return Uri.parse('$normalized/models');
      } else {
        return Uri.parse('$normalized/v1/models');
      }
    } else {
      if (normalized.endsWith('/models')) {
        return Uri.parse(normalized);
      }
      return Uri.parse('$normalized/models');
    }
  }

  /// Resolves the chat/messages endpoint for the given base URL and protocol.
  /// - OpenAI-compatible: appends `/chat/completions` (or `/responses` for codex).
  /// - Anthropic-compatible: appends `/messages` if ending in `/v1`, else `/v1/messages`.
  static Uri resolveChatEndpoint(String baseUrl, String protocol) {
    final normalized = normalizeBaseUrl(baseUrl);
    if (protocol == ProviderProtocol.anthropicCompatible) {
      if (normalized.endsWith('/v1')) {
        return Uri.parse('$normalized/messages');
      } else {
        return Uri.parse('$normalized/v1/messages');
      }
    } else {
      if (normalized.endsWith('/chat/completions')) {
        return Uri.parse(normalized);
      }
      return Uri.parse('$normalized/chat/completions');
    }
  }
}
