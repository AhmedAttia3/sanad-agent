import 'package:logging/logging.dart';

import 'package:sanad_agent/core/provider_runtime/env_file_service.dart';
import 'package:sanad_agent/core/provider_runtime/provider_credential_store.dart';
import 'package:sanad_agent/core/utils/credential_sanitizer.dart';
import 'package:sanad_agent/engine/adapters/provider_registry.dart';

/// Handles writes that add or remove provider setup data in `.env` and the
/// credential store. Read access lives in `ProviderStateService`.
///
/// Storage rules (per the plan):
/// - Simple API keys + base URLs + model names go to `.env`.
/// - OAuth tokens go to `ProviderCredentialStore`, never `.env`.
/// - Removing a provider only clears its own keys, never other providers'.
class ProviderConfigService {
  final _logger = Logger('ProviderConfigService');

  final EnvFileService _env;
  final ProviderCredentialStore _credStore;

  ProviderConfigService(this._env, this._credStore);

  /// Saves an API key for [providerId]. Optionally overrides the base URL and
  /// model. Does not change the active provider unless [makeActive] is true.
  Future<void> saveApiKey({
    required String providerId,
    required String apiKey,
    String? baseUrl,
    String? model,
    bool makeActive = false,
  }) async {
    final profile = ProviderRegistry.findByNameOrAlias(providerId);
    final sanitizedKey = sanitizeCredential(apiKey);

    final updates = <String, String>{};
    if (profile != null && profile.envApiKeyName != null) {
      updates[profile.envApiKeyName!] = sanitizedKey;
    }
    updates['LLM_API_KEY'] = sanitizedKey;

    if (baseUrl != null && baseUrl.trim().isNotEmpty) {
      updates['LLM_BASE_URL'] = baseUrl;
      if (profile != null && profile.envBaseUrlName != null) {
        updates[profile.envBaseUrlName!] = baseUrl;
      }
    } else if (profile != null && profile.defaultBaseUrl != null) {
      // Ensure a base URL is present so resolution is deterministic.
      final existing = profile.envBaseUrlName != null
          ? _env.get(profile.envBaseUrlName!)
          : _env.get('LLM_BASE_URL');
      if (existing.trim().isEmpty) {
        updates['LLM_BASE_URL'] = profile.defaultBaseUrl!;
        if (profile.envBaseUrlName != null) {
          updates[profile.envBaseUrlName!] = profile.defaultBaseUrl!;
        }
      }
    }

    if (model != null && model.trim().isNotEmpty) {
      updates['LLM_MODEL'] = model;
      if (profile != null && profile.envModelName != null) {
        updates[profile.envModelName!] = model;
      }
    }

    if (makeActive) {
      updates['ACTIVE_PROVIDER'] = profile?.name ?? providerId;
    }

    await _env.upsert(updates);
    _logger.fine('Saved API key for ${profile?.name ?? providerId}');
  }

  /// Saves a custom/local endpoint. The key is optional for local engines.
  Future<void> saveCustomEndpoint({
    required String baseUrl,
    required String model,
    String? apiKey,
    String? providerId,
    bool makeActive = false,
  }) async {
    final profile = providerId != null
        ? ProviderRegistry.findByNameOrAlias(providerId)
        : null;
    final updates = <String, String>{
      'LLM_BASE_URL': baseUrl,
      'LLM_MODEL': model,
    };

    if (profile != null) {
      if (profile.envBaseUrlName != null) {
        updates[profile.envBaseUrlName!] = baseUrl;
      }
      if (profile.envModelName != null) {
        updates[profile.envModelName!] = model;
      }
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        final sanitized = sanitizeCredential(apiKey);
        if (profile.envApiKeyName != null) {
          updates[profile.envApiKeyName!] = sanitized;
        }
        updates['LLM_API_KEY'] = sanitized;
      }
      if (makeActive) {
        updates['ACTIVE_PROVIDER'] = profile.name;
      }
    } else {
      if (apiKey != null && apiKey.trim().isNotEmpty) {
        updates['LLM_API_KEY'] = sanitizeCredential(apiKey);
      }
      if (makeActive) {
        updates['ACTIVE_PROVIDER'] = providerId ?? 'custom';
      }
    }

    await _env.upsert(updates);
    _logger.fine('Saved custom endpoint for ${profile?.name ?? 'custom'}');
  }

  /// Removes a provider's stored configuration. Only clears that provider's
  /// own keys and never touches other providers. When [deactivate] is true and
  /// the removed provider was active, the active selection is cleared.
  Future<void> remove({
    required String providerId,
    bool deactivate = true,
  }) async {
    final profile = ProviderRegistry.findByNameOrAlias(providerId);
    final keysToRemove = <String>{};

    if (profile != null) {
      if (profile.envApiKeyName != null) {
        keysToRemove.add(profile.envApiKeyName!);
      }
      if (profile.envModelName != null) keysToRemove.add(profile.envModelName!);
      if (profile.envBaseUrlName != null) {
        keysToRemove.add(profile.envBaseUrlName!);
      }
    }

    // OAuth tokens live in the credential store.
    if (profile != null && profile.isOAuth) {
      await _credStore.remove(profile.name);
    }

    await _env.removeKeys(keysToRemove);

    if (deactivate) {
      final active = _env.get('ACTIVE_PROVIDER').trim().toLowerCase();
      final thisId = profile?.name.toLowerCase() ?? providerId.toLowerCase();
      if (active == thisId) {
        await _env.removeKeys(const ['ACTIVE_PROVIDER']);
      }
    }
    _logger.fine('Removed provider ${profile?.name ?? providerId}');
  }
}
