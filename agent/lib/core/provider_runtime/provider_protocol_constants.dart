/// Centralized vocabulary for the Provider Template/Instance model (Plan 29).
///
/// These constants replace magic strings across the catalog, repository,
/// runtime, and protocol layers. They MUST be used instead of raw literals.
library;

/// High-level wire protocol a provider speaks. Drives `ProviderEndpointResolver`
/// and adapter selection. `ProviderTemplate.protocol` is one of these.
class ProviderProtocol {
  ProviderProtocol._();

  /// OpenAI-compatible REST shape (`/models`, `/v1/chat/completions`,
  /// `/responses`). Covers OpenAI, OpenRouter, Gemini OSS proxy, DeepSeek,
  /// Kimi, xAI, NVIDIA NIM, Ollama, LM Studio, llama.cpp and Custom gateways.
  static const openaiCompatible = 'openai_compatible';

  /// Anthropic-native message shape (`/v1/models`, `/v1/messages` with
  /// `x-api-key` + `anthropic-version`).
  static const anthropicCompatible = 'anthropic_compatible';

  static const all = <String>[openaiCompatible, anthropicCompatible];

  static bool isValid(String value) => all.contains(value);
}

/// Whether an API key is required to make a template usable.
class ApiKeyRequirement {
  ApiKeyRequirement._();

  /// Official cloud templates that mandate a key (OpenAI, Anthropic, ...).
  static const required = 'required';

  /// Local engines, Custom Provider, and OAuth-only templates: a key is
  /// accepted but not mandatory. An optional instance saved without a key
  /// surfaces `No API key` inside the API Keys category, never as a missing
  /// credential failure.
  static const optional = 'optional';

  static const all = <String>[required, optional];

  static bool isValid(String value) => all.contains(value);
}

/// Explicit authentication methods a template advertises. The instance stores
/// the method the user actually chose. Badge mapping (Plan 29 §6.1):
/// `Account` ← `deviceCode`/`loopback`/`external`; `API Key` ← `apiKey`/
/// `customEndpoint`.
class ProviderAuthMethod {
  ProviderAuthMethod._();

  static const apiKey = 'api_key';
  static const deviceCode = 'device_code';
  static const loopback = 'loopback';
  static const external = 'external';

  /// Methods that classify under the "Account" badge.
  static const accountMethods = <String>[deviceCode, loopback, external];

  /// Methods that classify under the "API Key" badge. Custom/local providers
  /// use `apiKey` with `ApiKeyRequirement.optional`; `customEndpoint` is NOT a
  /// valid `auth_method` value (it is a legacy `authFlow` string only).
  static const apiKeyMethods = <String>[apiKey];

  static bool isAccountMethod(String method) => accountMethods.contains(method);

  static bool isApiKeyMethod(String method) => apiKeyMethods.contains(method);
}

/// Lifecycle status of a `ProviderInstance` (Plan 29 §7.2).
class InstanceStatus {
  InstanceStatus._();

  /// Created but not yet validated/credentialled; cannot become default.
  static const draft = 'draft';

  /// Fully usable: credential + endpoint + model resolve cleanly.
  static const ready = 'ready';

  /// Credential missing or expired (OAuth re-login / key removed).
  static const needsAuth = 'needs_auth';

  /// Endpoint test failed or configuration is invalid.
  static const error = 'error';

  static const all = <String>[draft, ready, needsAuth, error];

  static bool isValid(String value) => all.contains(value);
}

/// Credential edit actions for `provider.credential.update` (Plan 29 §7.5).
/// `keep` is the default; an empty field never implies `remove`.
class CredentialAction {
  CredentialAction._();

  static const keep = 'keep';
  static const replace = 'replace';
  static const remove = 'remove';

  static const all = <String>[keep, replace, remove];

  static bool isValid(String value) => all.contains(value);
}

/// Reserved template id for a user-defined provider that is neither officially
/// registered nor a hardcoded gateway name (Plan 29 §7.1). Custom instances
/// must declare an explicit protocol + base URL at creation time.
const kCustomProviderTemplateId = 'custom';
