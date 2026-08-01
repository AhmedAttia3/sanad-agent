import 'package:logging/logging.dart';

import 'package:sanad_agent/core/provider_runtime/env_file_service.dart';
import 'package:sanad_agent/engine/adapters/provider_registry.dart';

/// Persists the active provider + default model selection into `.env`,
/// updating both the generic fields (`ACTIVE_PROVIDER`, `LLM_MODEL`,
/// `LLM_BASE_URL`, `LLM_API_KEY`) and the provider-specific fields.
///
/// Changing the active provider never deletes other providers' settings.
class ModelSelectionService {
  final _logger = Logger('ModelSelectionService');

  final EnvFileService _env;

  ModelSelectionService(this._env);

  /// Recommends a default model for [providerId]: the currently selected model
  /// if any, otherwise the first fallback model.
  String recommendedDefault(String providerId) {
    final profile = ProviderRegistry.findByNameOrAlias(providerId);
    if (profile == null) return '';
    if (profile.envModelName != null) {
      final v = _env.get(profile.envModelName!);
      if (v.trim().isNotEmpty) return v;
    }
    final active = _env.get('ACTIVE_PROVIDER').trim().toLowerCase();
    if (active.isEmpty || active == profile.name) {
      final generic = _env.get('LLM_MODEL');
      if (generic.trim().isNotEmpty) return generic;
    }
    if (profile.fallbackModels.isNotEmpty) return profile.fallbackModels.first;
    return '';
  }

  /// Persists [providerId] as the active provider with [model] as the default
  /// model. Optional [baseUrl] overrides the provider default.
  Future<void> setDefault({
    required String providerId,
    required String model,
    String? baseUrl,
    String? apiKey,
  }) async {
    final profile = ProviderRegistry.findByNameOrAlias(providerId);
    final updates = <String, String>{
      'ACTIVE_PROVIDER': profile?.name ?? providerId,
      'LLM_MODEL': model,
    };

    if (profile != null) {
      if (profile.envModelName != null) {
        updates[profile.envModelName!] = model;
      }
      final effectiveBaseUrl =
          baseUrl ??
          (profile.envBaseUrlName != null
              ? _env.get(profile.envBaseUrlName!)
              : null) ??
          profile.defaultBaseUrl ??
          '';
      if (effectiveBaseUrl.isNotEmpty) {
        updates['LLM_BASE_URL'] = effectiveBaseUrl;
        if (profile.envBaseUrlName != null) {
          updates[profile.envBaseUrlName!] = effectiveBaseUrl;
        }
      }
      if (profile.envApiKeyName != null && apiKey != null) {
        updates[profile.envApiKeyName!] = apiKey;
        updates['LLM_API_KEY'] = apiKey;
      }
    } else if (baseUrl != null) {
      updates['LLM_BASE_URL'] = baseUrl;
    }

    await _env.upsert(updates);
    _logger.fine(
      'Default model set: provider=${profile?.name ?? providerId} model=$model',
    );
  }
}
