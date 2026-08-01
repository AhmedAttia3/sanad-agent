class ProviderTemplateDto {
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

  /// Canonical wire protocol (Plan 29 §11.1): `openai_compatible` or
  /// `anthropic_compatible`. Drives adapter selection and URL normalization.
  /// Received from the agent's `provider.templates.list` payload.
  final String protocol;

  /// `required` or `optional` (Plan 29 §7.1). Determines whether an empty API
  /// key is rejected or accepted for optional/custom providers.
  final String apiKeyRequirement;

  /// Explicit auth methods advertised by the template (e.g. `['api_key']` or
  /// `['device_code', 'api_key']`).
  final List<String> authMethods;

  /// Compatibility projection for the dormant local rate limiter. Task 57
  /// requires every template to advertise `0` (unlimited).
  final int defaultRequestsPerMinute;

  const ProviderTemplateDto({
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
    this.protocol = 'openai_compatible',
    this.apiKeyRequirement = 'required',
    this.authMethods = const ['api_key'],
    this.defaultRequestsPerMinute = 0,
  });

  /// Whether this template requires a non-empty API key.
  bool get isApiKeyOptional => apiKeyRequirement == 'optional';

  /// Canonical methods used by setup when older payloads omit the list.
  List<String> get effectiveAuthMethods => authMethods.isEmpty ? const ['api_key'] : authMethods;

  factory ProviderTemplateDto.fromJson(Map<String, dynamic> json) {
    final fallbackModels = (json['fallback_models'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final aliases = (json['aliases'] as List?)?.map((e) => e.toString()).toList() ?? const <String>[];
    final authMethods = (json['auth_methods'] as List?)?.map((e) => e.toString()).toList() ?? const <String>['api_key'];
    return ProviderTemplateDto(
      name: (json['name'] ?? '').toString(),
      displayName: (json['display_name'] ?? '').toString(),
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
      protocol: (json['protocol'] ?? 'openai_compatible').toString(),
      apiKeyRequirement: (json['api_key_requirement'] ?? 'required').toString(),
      authMethods: authMethods,
      defaultRequestsPerMinute: (json['default_requests_per_minute'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
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
    'protocol': protocol,
    'api_key_requirement': apiKeyRequirement,
    'auth_methods': authMethods,
    'default_requests_per_minute': defaultRequestsPerMinute,
  };
}
