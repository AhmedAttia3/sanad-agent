import 'dart:io';

import 'package:sanad_agent/core/constants.dart';
import 'package:sanad_agent/core/provider_runtime/env_file_service.dart';
import 'package:sanad_agent/core/provider_runtime/provider_credential_store.dart';
import 'package:sanad_agent/core/provider_runtime/provider_state_service.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempWorkDir;
  late Directory tempSanadHome;

  setUp(() async {
    tempWorkDir = await Directory.systemTemp.createTemp('sanad-provider-state');
    tempSanadHome = await Directory.systemTemp.createTemp(
      'sanad-provider-home',
    );
    setSanadHomeOverride(tempSanadHome.path);
  });

  tearDown(() async {
    setSanadHomeOverride(null);
    if (tempWorkDir.existsSync()) await tempWorkDir.delete(recursive: true);
    if (tempSanadHome.existsSync()) await tempSanadHome.delete(recursive: true);
  });

  EnvFileService envWith(String content) {
    final file = File('${tempWorkDir.path}/.env');
    file.writeAsStringSync(content);
    return EnvFileService(envPath: file.path);
  }

  test('API key provider saved in .env is configured and current', () {
    final env = envWith('''
ACTIVE_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-test
OPENROUTER_MODEL=mistralai/mistral-large-2512
''');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    final service = ProviderStateService(env, credStore);

    final openrouter = service.allStates().firstWhere(
      (s) => s.id == 'openrouter',
    );
    expect(openrouter.configured, isTrue);
    expect(openrouter.authenticated, isTrue);
    expect(openrouter.isCurrent, isTrue);
    expect(openrouter.selectedModel, equals('mistralai/mistral-large-2512'));
    expect(openrouter.authStatus, equals('authenticated'));
  });

  test('more than one provider can be saved simultaneously', () {
    final env = envWith('''
ACTIVE_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-test
OPENAI_API_KEY=sk-openai-test
OPENAI_MODEL=gpt-4o
''');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    final service = ProviderStateService(env, credStore);

    final states = service.allStates();
    final openrouter = states.firstWhere((s) => s.id == 'openrouter');
    final openai = states.firstWhere((s) => s.id == 'openai');

    expect(openrouter.configured, isTrue);
    expect(openrouter.isCurrent, isTrue);
    expect(openai.configured, isTrue);
    expect(openai.isCurrent, isFalse);
    expect(openai.selectedModel, equals('gpt-4o'));
  });

  test('active provider differs from a saved provider', () {
    final env = envWith('''
ACTIVE_PROVIDER=anthropic
ANTHROPIC_API_KEY=sk-anthropic-test
OPENROUTER_API_KEY=sk-or-test
''');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    final service = ProviderStateService(env, credStore);

    final states = service.allStates();
    final anthropic = states.firstWhere((s) => s.id == 'anthropic');
    final openrouter = states.firstWhere((s) => s.id == 'openrouter');

    expect(anthropic.isCurrent, isTrue);
    expect(openrouter.isCurrent, isFalse);
    expect(openrouter.configured, isTrue);
  });

  test('OAuth provider saved in credential store is authenticated', () async {
    final env = envWith('ACTIVE_PROVIDER=openai-codex');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    await credStore.write(
      ProviderAuthRecord(
        providerId: 'openai-codex',
        accessToken: 'access-123',
        refreshToken: 'refresh-456',
        expiresAt: DateTime.now()
            .add(const Duration(hours: 1))
            .millisecondsSinceEpoch,
        status: 'authenticated',
      ),
    );
    final service = ProviderStateService(env, credStore);
    final codex = service.allStates().firstWhere((s) => s.id == 'openai-codex');
    expect(codex.configured, isTrue);
    expect(codex.authenticated, isTrue);
    expect(codex.isCurrent, isTrue);
    expect(codex.authStatus, equals('authenticated'));
  });

  test('legacy .env token without OAuth session is relogin_required', () {
    final env = envWith('''
ACTIVE_PROVIDER=openai-codex
CHATGPT_SESSION_TOKEN=legacy-token
''');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    final service = ProviderStateService(env, credStore);
    final codex = service.allStates().firstWhere((s) => s.id == 'openai-codex');
    expect(codex.configured, isTrue);
    expect(codex.authenticated, isFalse);
    expect(codex.authStatus, equals('relogin_required'));
    expect(codex.warning, isNotNull);
  });

  test('providersPayload returns unified contract shape', () {
    final env = envWith('''
ACTIVE_PROVIDER=openrouter
OPENROUTER_API_KEY=sk-or-test
LLM_MODEL=mistralai/mistral-large-2512
''');
    final credStore = ProviderCredentialStore(
      storePath: '${tempSanadHome.path}/provider_auth.json',
    );
    final service = ProviderStateService(env, credStore);
    final payload = service.providersPayload();

    expect(payload['active_provider'], equals('openrouter'));
    expect(payload['active_model'], equals('mistralai/mistral-large-2512'));
    expect(payload['providers'], isA<List>());
  });
}
