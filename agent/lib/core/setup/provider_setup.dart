import 'dart:io';
import 'package:sanad_agent/core/setup/setup_helpers.dart';
import 'package:sanad_agent/engine/adapters/provider_registry.dart';
import 'package:sanad_agent/engine/adapters/provider_profile.dart';
import 'package:sanad_agent/core/utils/terminal_prompts.dart';

/// The result of running a provider sub-flow setup.
class ProviderSetupResult {
  final String llmBaseUrl;
  final String llmModel;
  final String llmApiKey;

  ProviderSetupResult({
    required this.llmBaseUrl,
    required this.llmModel,
    required this.llmApiKey,
  });
}

/// A dedicated manager that handles the prompting, credential collecting,
/// and validation logic for each specific AI provider.
class ProviderSetupManager {
  final Map<String, String> existingEnv;

  ProviderSetupManager(this.existingEnv);

  String maskKey(String key) {
    if (key.length <= 8) return '***';
    return '${key.substring(0, 4)}...${key.substring(key.length - 4)}';
  }

  bool isActiveProvider(String? profileName, String? defaultBaseUrl) {
    final active = existingEnv['ACTIVE_PROVIDER']?.trim().toLowerCase() ?? '';
    if (active.isNotEmpty && profileName != null) {
      return active == profileName.toLowerCase();
    }
    if (defaultBaseUrl != null) {
      final currentBaseUrl = existingEnv['LLM_BASE_URL'] ?? '';
      return currentBaseUrl.startsWith(defaultBaseUrl) ||
          defaultBaseUrl.startsWith(currentBaseUrl);
    }
    return false;
  }

  String promptKey(
    String label, {
    String? envApiKeyName,
    String? profileName,
    String? defaultBaseUrl,
  }) {
    String? existingVal;
    if (envApiKeyName != null) {
      existingVal = existingEnv[envApiKeyName];
    }
    // Only fall back to LLM_API_KEY if the provider is currently active
    if ((existingVal == null || existingVal.isEmpty) &&
        isActiveProvider(profileName, defaultBaseUrl)) {
      existingVal = existingEnv['LLM_API_KEY'];
    }

    if (existingVal != null &&
        existingVal.isNotEmpty &&
        existingVal != 'your_key_here') {
      stdout.write('Enter your $label (default: ${maskKey(existingVal)}): ');
      final input = stdin.readLineSync()?.trim();
      return (input != null && input.isNotEmpty) ? input : existingVal;
    } else {
      stdout.write('Enter your $label: ');
      return stdin.readLineSync()?.trim() ?? '';
    }
  }

  String promptValue(
    String promptLabel,
    String defaultValue, {
    String? existingVal,
  }) {
    final displayDefault = existingVal ?? defaultValue;
    stdout.write('$promptLabel (default: $displayDefault): ');
    final input = stdin.readLineSync()?.trim();
    return (input != null && input.isNotEmpty) ? input : displayDefault;
  }

  String? activeModelForProvider(String? providerName, String defaultModel) {
    if (providerName != null) {
      final profile = ProviderRegistry.findByNameOrAlias(providerName);
      if (profile != null && profile.envModelName != null) {
        final specModel = existingEnv[profile.envModelName!];
        if (specModel != null && specModel.isNotEmpty) {
          return specModel;
        }
      }
    }
    return existingEnv['LLM_MODEL'];
  }

  Future<ProviderSetupResult> runSetup(
    String providerChoice,
    String? profileName,
    ProviderProfile? profile,
  ) async {
    String llmBaseUrl = 'https://api.openai.com/v1';
    String llmModel = 'gpt-4o';
    String llmApiKey = '';

    if (profileName == null) {
      // ── Custom Setup ──
      print('\n--- Custom API Setup ---');
      final isCustom = !ProviderRegistry.profiles.any(
        (p) =>
            (existingEnv['LLM_BASE_URL'] ?? '').toLowerCase().contains(p.name),
      );

      llmBaseUrl = promptValue(
        'Enter custom API Base URL (e.g., http://localhost:8080/v1)',
        'http://localhost:8080/v1',
        existingVal: isCustom ? existingEnv['LLM_BASE_URL'] : null,
      );

      stdout.write(
        'Enter model name${isCustom && existingEnv['LLM_MODEL'] != null ? " (default: ${existingEnv['LLM_MODEL']})" : ""}: ',
      );
      final customModelInput = stdin.readLineSync()?.trim();
      llmModel = (customModelInput != null && customModelInput.isNotEmpty)
          ? customModelInput
          : (isCustom ? (existingEnv['LLM_MODEL'] ?? '') : '');

      llmApiKey = promptKey(
        'API Key (optional)',
        envApiKeyName: isCustom ? 'LLM_API_KEY' : null,
        profileName: 'custom',
      );
    } else if (profileName == 'openai-codex') {
      // ── ChatGPT Plus Subscription ──
      llmBaseUrl = 'https://chatgpt.com/backend-api/codex';
      print('\n--- ChatGPT Plus Subscription Setup ---');
      final methodIdx = selectInteractive('Choose authentication method:', [
        'Device Code Login (Recommended - Open browser and enter a code)',
        'Manual Session Token (Enter __Secure-next-auth.session-token)',
      ]);

      if (methodIdx == 1) {
        llmApiKey = promptKey(
          'ChatGPT session token (__Secure-next-auth.session-token)',
          envApiKeyName: 'CHATGPT_SESSION_TOKEN',
          profileName: 'openai-codex',
          defaultBaseUrl: llmBaseUrl,
        );
      } else {
        final token = await runCodexDeviceCodeFlow();
        if (token != null && token.isNotEmpty) {
          llmApiKey = token;
        } else {
          print('\n⚠️ Device authentication flow failed or was cancelled.');
          print('Falling back to manual session token input...');
          llmApiKey = promptKey(
            'ChatGPT session token (__Secure-next-auth.session-token)',
            envApiKeyName: 'CHATGPT_SESSION_TOKEN',
            profileName: 'openai-codex',
            defaultBaseUrl: llmBaseUrl,
          );
        }
      }

      llmModel = await promptModelSelection(
        profile!,
        activeModelForProvider('openai-codex', 'gpt-4o') ?? 'gpt-4o',
        llmBaseUrl: llmBaseUrl,
        llmApiKey: llmApiKey,
      );
    } else if (profileName == 'xai-oauth') {
      // ── Grok Subscription ──
      llmBaseUrl = 'https://x.com/i/api/v1/grok';
      print('\n--- Grok Subscription Setup ---');
      llmApiKey = promptKey(
        'Grok session token (auth_token cookie)',
        envApiKeyName: 'GROK_SESSION_TOKEN',
        profileName: 'xai-oauth',
        defaultBaseUrl: llmBaseUrl,
      );
      llmModel = await promptModelSelection(
        profile!,
        activeModelForProvider('xai-oauth', 'grok-2') ?? 'grok-2',
        llmBaseUrl: llmBaseUrl,
        llmApiKey: llmApiKey,
      );
    } else {
      // ── Generic Data-Driven Provider Setup (OpenAI, Anthropic, Gemini, NVIDIA, DeepSeek, Ollama, etc.) ──
      final displayName = profile!.displayName;
      print('\n--- $displayName Setup ---');

      final defaultUrl = profile.defaultBaseUrl ?? '';
      final isCurrentlyActive = isActiveProvider(profileName, defaultUrl);
      final currentBaseUrl = existingEnv['LLM_BASE_URL'] ?? '';
      if (profile.envBaseUrlName != null) {
        final specBaseUrl = existingEnv[profile.envBaseUrlName!];
        llmBaseUrl = promptValue(
          'Enter $displayName base URL',
          defaultUrl,
          existingVal: (specBaseUrl != null && specBaseUrl.isNotEmpty)
              ? specBaseUrl
              : (isCurrentlyActive ? currentBaseUrl : null),
        );
      } else {
        llmBaseUrl = defaultUrl;
      }

      if (profile.envApiKeyName != null) {
        llmApiKey = promptKey(
          '$displayName API Key',
          envApiKeyName: profile.envApiKeyName,
          profileName: profileName,
          defaultBaseUrl: llmBaseUrl,
        );
      } else {
        llmApiKey = '';
      }

      final fallbackModel = profile.fallbackModels.isNotEmpty
          ? profile.fallbackModels.first
          : 'gpt-4o';
      final currentModel =
          activeModelForProvider(profileName, fallbackModel) ?? fallbackModel;

      llmModel = await promptModelSelection(
        profile,
        currentModel,
        llmBaseUrl: llmBaseUrl,
        llmApiKey: llmApiKey,
      );
    }

    return ProviderSetupResult(
      llmBaseUrl: llmBaseUrl,
      llmModel: llmModel,
      llmApiKey: llmApiKey,
    );
  }
}
