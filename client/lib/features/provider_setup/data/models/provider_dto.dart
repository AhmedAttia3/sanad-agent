/// Compatibility DTO for provider templates projected into the older picker
/// shape used by some widgets during the Plan 29 migration.
///
/// Combines the agent's catalog fields (description, docs URL, fallback
/// models, fetch capability, disconnectable flag) with the live state fields
/// (configured, authenticated, is_current, selected_model, auth_status).
/// The agent's `ProviderRegistry` is the single source of truth; the client
/// must never hardcode this list.
class ProviderDto {
  final String id;
  final String name;
  final String displayName;
  final String description;
  final String? defaultBaseUrl;
  final String? keyEnv;
  final String? envModelName;
  final String? envBaseUrlName;
  final String authType;
  final String authFlow;
  final String apiMode;
  final String? docsUrl;
  final bool supportsModelFetch;
  final bool disconnectable;
  final List<String> fallbackModels;
  final List<String> aliases;

  final bool configured;
  final bool authenticated;
  final bool isCurrent;
  final List<String> models;
  final String? selectedModel;
  final String authStatus;
  final String? warning;

  const ProviderDto({
    required this.id,
    required this.name,
    required this.displayName,
    required this.description,
    this.defaultBaseUrl,
    this.keyEnv,
    this.envModelName,
    this.envBaseUrlName,
    required this.authType,
    required this.authFlow,
    required this.apiMode,
    this.docsUrl,
    required this.supportsModelFetch,
    required this.disconnectable,
    required this.fallbackModels,
    required this.aliases,
    required this.configured,
    required this.authenticated,
    required this.isCurrent,
    required this.models,
    this.selectedModel,
    required this.authStatus,
    this.warning,
  });

  bool get isOAuth => authType == 'external' || authType == 'device_code' || authType == 'loopback';

  factory ProviderDto.fromJson(Map<String, dynamic> json) {
    final models = (json['models'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final fallbackModels = (json['fallback_models'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final aliases = (json['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    return ProviderDto(
      id: (json['id'] ?? json['name'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      displayName: (json['display_name'] ?? json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      defaultBaseUrl: json['default_base_url']?.toString(),
      keyEnv: json['key_env']?.toString(),
      envModelName: json['env_model_name']?.toString(),
      envBaseUrlName: json['env_base_url_name']?.toString(),
      authType: (json['auth_type'] ?? 'api_key').toString(),
      authFlow: (json['auth_flow'] ?? 'api_key').toString(),
      apiMode: (json['api_mode'] ?? 'chat_completions').toString(),
      docsUrl: json['docs_url']?.toString(),
      supportsModelFetch: (json['supports_model_fetch'] as bool?) ?? true,
      disconnectable: (json['disconnectable'] as bool?) ?? true,
      fallbackModels: fallbackModels,
      aliases: aliases,
      configured: (json['configured'] as bool?) ?? false,
      authenticated: (json['authenticated'] as bool?) ?? false,
      isCurrent: (json['is_current'] as bool?) ?? false,
      models: models,
      selectedModel: json['selected_model']?.toString(),
      authStatus: (json['auth_status'] ?? 'missing').toString(),
      warning: json['warning']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'display_name': displayName,
    'description': description,
    if (defaultBaseUrl != null) 'default_base_url': defaultBaseUrl,
    if (keyEnv != null) 'key_env': keyEnv,
    if (envModelName != null) 'env_model_name': envModelName,
    if (envBaseUrlName != null) 'env_base_url_name': envBaseUrlName,
    'auth_type': authType,
    'auth_flow': authFlow,
    'api_mode': apiMode,
    if (docsUrl != null) 'docs_url': docsUrl,
    'supports_model_fetch': supportsModelFetch,
    'disconnectable': disconnectable,
    'fallback_models': fallbackModels,
    'aliases': aliases,
    'configured': configured,
    'authenticated': authenticated,
    'is_current': isCurrent,
    'models': models,
    if (selectedModel != null) 'selected_model': selectedModel,
    'auth_status': authStatus,
    if (warning != null) 'warning': warning,
  };

  @override
  String toString() => 'ProviderDto(id: $id, configured: $configured, isCurrent: $isCurrent)';
}

/// Parsed response containing provider entries plus active provider/model
/// identifiers. Kept for temporary compatibility during the migration.
class ProviderListResult {
  final List<ProviderDto> providers;
  final String? activeProvider;
  final String? activeModel;

  const ProviderListResult({
    required this.providers,
    this.activeProvider,
    this.activeModel,
  });

  factory ProviderListResult.fromJson(Map<String, dynamic> json) {
    final list =
        (json['providers'] as List?)?.map((e) => ProviderDto.fromJson(e as Map<String, dynamic>)).toList() ??
        const <ProviderDto>[];
    return ProviderListResult(
      providers: list,
      activeProvider: json['active_provider']?.toString(),
      activeModel: json['active_model']?.toString(),
    );
  }
}
