import 'package:sanad_agent/core/provider_runtime/env_file_service.dart';
import 'package:sanad_agent/core/provider_runtime/provider_credential_store.dart';
import 'package:sanad_agent/engine/adapters/provider_profile.dart';
import 'package:sanad_agent/engine/adapters/provider_registry.dart';

/// Per-provider resolved state, suitable for serialization to the client.
class ProviderState {
  final String id;
  final String displayName;
  final String authType;
  final String authFlow;

  /// Whether any usable setup data exists (env key, OAuth token, or local
  /// endpoint).
  final bool configured;

  /// Whether the OAuth session (if applicable) is currently authenticated.
  /// For api_key providers this mirrors [configured].
  final bool authenticated;

  /// Whether this is the currently active provider.
  final bool isCurrent;

  /// Models offered by this provider (fallback list or fetched list).
  final List<String> models;

  /// Currently selected model for this provider, if any.
  final String? selectedModel;

  /// Env var name holding the API key (presentation hint for the UI).
  final String? keyEnv;

  /// Auth status string for OAuth providers: `authenticated`, `expired`,
  /// `relogin_required`, `refreshing`, or `missing`. `none` for api_key.
  final String authStatus;

  /// Optional warning text surfaced to the UI (e.g. expired token).
  final String? warning;

  ProviderState({
    required this.id,
    required this.displayName,
    required this.authType,
    required this.authFlow,
    required this.configured,
    required this.authenticated,
    required this.isCurrent,
    required this.models,
    required this.selectedModel,
    required this.keyEnv,
    required this.authStatus,
    this.warning,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'display_name': displayName,
    'configured': configured,
    'authenticated': authenticated,
    'is_current': isCurrent,
    'auth_type': authType,
    'auth_flow': authFlow,
    'models': models,
    if (selectedModel != null) 'selected_model': selectedModel,
    if (keyEnv != null) 'key_env': keyEnv,
    'auth_status': authStatus,
    if (warning != null) 'warning': warning,
  };
}

/// Reads `.env` and `ProviderCredentialStore` and produces a unified provider
/// state view consumed by both CLI and Flutter. It does not mutate storage;
/// use `ModelSelectionService` / `ProviderCredentialStore` for writes.
class ProviderStateService {
  final EnvFileService _env;
  final ProviderCredentialStore _credStore;

  ProviderStateService(this._env, this._credStore);

  String get _activeProviderRaw =>
      _env.get('ACTIVE_PROVIDER').trim().toLowerCase();

  /// Resolves the active provider id, falling back to env auto-detection
  /// (mirrors `Config.resolveProviderName`) but without needing a `Config`
  /// instance so it stays testable.
  String resolveActiveProviderId() {
    final explicit = _activeProviderRaw;
    if (explicit.isNotEmpty) {
      final match = ProviderRegistry.findByNameOrAlias(explicit);
      if (match != null) return match.name;
      return explicit;
    }
    final baseUrl = _env.get('LLM_BASE_URL').toLowerCase();
    final model = _env.get('LLM_MODEL').toLowerCase();
    if (baseUrl.contains('chatgpt.com') || baseUrl.contains('openai-codex')) {
      return 'openai-codex';
    } else if (baseUrl.contains('x.com') ||
        baseUrl.contains('grok-subscription') ||
        baseUrl.contains('xai-oauth')) {
      return 'xai-oauth';
    } else if (baseUrl.contains('anthropic') || model.startsWith('claude')) {
      return 'anthropic';
    } else if (baseUrl.contains('openrouter')) {
      return 'openrouter';
    } else if (baseUrl.contains('googleapis.com') ||
        model.startsWith('gemini')) {
      return 'gemini';
    } else if (baseUrl.contains('deepseek')) {
      return 'deepseek';
    } else if (baseUrl.contains('x.ai') || baseUrl.contains('grok')) {
      return 'xai';
    } else if (baseUrl.contains('11434') || baseUrl.contains('ollama')) {
      return 'ollama';
    } else if (baseUrl.contains('nvidia')) {
      return 'nvidia';
    } else if (baseUrl.isNotEmpty) {
      return 'custom';
    }
    return 'openai';
  }

  String? _selectedModelFor(ProviderProfile profile) {
    if (profile.envModelName != null) {
      final v = _env.get(profile.envModelName!);
      if (v.trim().isNotEmpty) return v;
    }
    final generic = _env.get('LLM_MODEL');
    if (generic.trim().isNotEmpty &&
        _isActiveProvider(profile.name, profile.defaultBaseUrl)) {
      return generic;
    }
    return null;
  }

  bool _isActiveProvider(String? profileName, String? defaultBaseUrl) {
    final active = _activeProviderRaw;
    if (active.isNotEmpty && profileName != null) {
      return active == profileName.toLowerCase();
    }
    if (defaultBaseUrl != null) {
      final currentBaseUrl = _env.get('LLM_BASE_URL');
      return currentBaseUrl.startsWith(defaultBaseUrl) ||
          defaultBaseUrl.startsWith(currentBaseUrl);
    }
    return false;
  }

  /// Builds the state for a single profile.
  ProviderState stateFor(ProviderProfile profile) {
    final activeId = resolveActiveProviderId();
    final isCurrent =
        activeId == profile.name ||
        _isActiveProvider(profile.name, profile.defaultBaseUrl);

    String? selectedModel = _selectedModelFor(profile);
    // Fallback to generic LLM_MODEL only when this is the active provider.
    if (selectedModel == null && isCurrent) {
      final generic = _env.get('LLM_MODEL');
      if (generic.trim().isNotEmpty) selectedModel = generic;
    }

    if (profile.isOAuth) {
      final record = _credStore.read(profile.name);
      final hasLegacyEnvToken =
          profile.envApiKeyName != null &&
          _env.get(profile.envApiKeyName!).trim().isNotEmpty;

      // A legacy env-only token (e.g. old CHATGPT_SESSION_TOKEN) is not enough
      // to consider the OAuth session authenticated; it must flow through the
      // credential resolver.
      final configured = record != null || hasLegacyEnvToken;
      String authStatus;
      bool authenticated;
      String? warning;
      if (record == null) {
        if (hasLegacyEnvToken) {
          authStatus = 'relogin_required';
          authenticated = false;
          warning =
              'A legacy token was found in .env but no OAuth session is '
              'stored. Please sign in again.';
        } else {
          authStatus = 'missing';
          authenticated = false;
        }
      } else if (record.isExpired) {
        if (record.refreshToken != null && record.refreshToken!.isNotEmpty) {
          authStatus = 'expired';
          authenticated = false;
          warning = 'Session expired. It can be refreshed automatically.';
        } else {
          authStatus = 'relogin_required';
          authenticated = false;
          warning = 'Session expired and no refresh token is available.';
        }
      } else {
        authStatus = record.status == 'relogin_required'
            ? 'relogin_required'
            : 'authenticated';
        authenticated = authStatus == 'authenticated';
      }

      return ProviderState(
        id: profile.name,
        displayName: profile.displayName,
        authType: profile.authType,
        authFlow: profile.effectiveAuthFlow,
        configured: configured,
        authenticated: authenticated,
        isCurrent: isCurrent,
        models: profile.fallbackModels,
        selectedModel: selectedModel,
        keyEnv: profile.envApiKeyName,
        authStatus: authStatus,
        warning: warning,
      );
    }

    // api_key / custom_endpoint providers
    final hasKey =
        profile.envApiKeyName != null &&
        _env.get(profile.envApiKeyName!).trim().isNotEmpty;
    final hasBaseUrl =
        profile.envBaseUrlName != null &&
        _env.get(profile.envBaseUrlName!).trim().isNotEmpty;
    final hasGenericKey = _env.get('LLM_API_KEY').trim().isNotEmpty;
    final isLocal =
        profile.name == 'ollama' ||
        profile.name == 'lm-studio' ||
        profile.name == 'llama-cpp';

    final configured =
        hasKey ||
        (isCurrent && hasGenericKey) ||
        (isLocal && hasBaseUrl) ||
        (hasBaseUrl && profile.authFlow == 'custom_endpoint');

    return ProviderState(
      id: profile.name,
      displayName: profile.displayName,
      authType: profile.authType,
      authFlow: profile.effectiveAuthFlow,
      configured: configured,
      authenticated: configured,
      isCurrent: isCurrent,
      models: profile.fallbackModels,
      selectedModel: selectedModel,
      keyEnv: profile.envApiKeyName,
      authStatus: configured ? 'authenticated' : 'missing',
    );
  }

  /// Builds state for every supported provider.
  List<ProviderState> allStates() =>
      ProviderRegistry.profiles.map(stateFor).toList();

  /// Builds state for providers that have any setup data.
  List<ProviderState> configuredStates() =>
      allStates().where((s) => s.configured).toList();

  /// Unified payload matching the plan's contract shape.
  Map<String, dynamic> providersPayload() {
    final states = allStates();
    final activeId = resolveActiveProviderId();
    final activeModel = _env.get('LLM_MODEL');
    return {
      'providers': states.map((s) => s.toMap()).toList(),
      'active_provider': activeId,
      if (activeModel.trim().isNotEmpty) 'active_model': activeModel,
    };
  }
}
