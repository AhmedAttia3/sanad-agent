import 'dart:io';

import 'package:sanad_agent/core/constants.dart';
import 'package:sanad_agent/core/provider_runtime/provider_instance.dart';
import 'package:sanad_agent/core/provider_runtime/provider_instance_repository.dart';
import 'package:sanad_agent/core/provider_runtime/provider_protocol_constants.dart';
import 'package:sanad_agent/core/provider_runtime/provider_readiness_service.dart';
import 'package:sanad_agent/core/provider_runtime/secret_record.dart';
import 'package:sanad_agent/core/provider_runtime/secret_store.dart';
import 'package:sanad_agent/core/provider_runtime/secure_file_secret_store.dart';
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late ProviderInstanceRepository repo;
  late SecretStore secretStore;
  late ProviderReadinessService service;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('sanad-readiness');
    setSanadHomeOverride(tempDir.path);
    repo = ProviderInstanceRepository.inMemory();
    secretStore = SecureFileSecretStore(
      storePath: '${tempDir.path}/secrets.json',
    );
    service = ProviderReadinessService(repo, secretStore);
  });

  tearDown(() {
    setSanadHomeOverride(null);
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  test('no instance configured -> not ready', () {
    final result = service.runtimeCheck();
    expect(result.hasProvider, isFalse);
    expect(result.runtimeReady, isFalse);
    expect(result.reason, isNotNull);
  });

  test('instance present but no model -> not ready', () {
    repo.createInstance(
      ProviderInstance(
        id: 'inst-1',
        templateId: 'openrouter',
        displayName: 'OpenRouter',
        protocol: ProviderProtocol.openaiCompatible,
        authMethod: ProviderAuthMethod.apiKey,
        status: InstanceStatus.draft,
        isDefault: true,
        configRevision: 1,
        credentialRevision: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    final result = service.runtimeCheck();
    expect(result.hasProvider, isTrue);
    expect(result.runtimeReady, isFalse);
    expect(result.reason, anyOf(contains('model'), contains('draft')));
  });

  test('instance ready with key and model', () async {
    repo.createInstance(
      ProviderInstance(
        id: 'inst-2',
        templateId: 'openrouter',
        displayName: 'OpenRouter',
        protocol: ProviderProtocol.openaiCompatible,
        authMethod: ProviderAuthMethod.apiKey,
        defaultModel: 'mistralai/mistral-large-2512',
        status: InstanceStatus.ready,
        isDefault: true,
        configRevision: 1,
        credentialRevision: 1,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ),
    );
    await secretStore.write(
      'inst-2',
      SecretRecord(
        instanceId: 'inst-2',
        apiKey: 'sk-or-test',
        authMethod: ProviderAuthMethod.apiKey,
      ),
    );
    final result = service.runtimeCheck();
    expect(result.hasProvider, isTrue);
    expect(result.runtimeReady, isTrue);
    expect(result.activeProvider, equals('inst-2'));
    expect(result.activeModel, equals('mistralai/mistral-large-2512'));
  });

  test(
    'instance with no default model fails closed (no fallback to _config)',
    () {
      repo.createInstance(
        ProviderInstance(
          id: 'inst-4',
          templateId: 'openai',
          displayName: 'OpenAI',
          protocol: ProviderProtocol.openaiCompatible,
          authMethod: ProviderAuthMethod.apiKey,
          status: InstanceStatus.draft,
          isDefault: true,
          configRevision: 1,
          credentialRevision: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final result = service.setupStatus();
      expect(result.hasProvider, isTrue);
      expect(result.runtimeReady, isFalse);
      expect(result.reason, anyOf(contains('model'), contains('Model')));
    },
  );

  test(
    'configured true but runtime check fails for OAuth without session',
    () async {
      repo.createInstance(
        ProviderInstance(
          id: 'inst-3',
          templateId: 'openai-codex',
          displayName: 'Codex',
          protocol: ProviderProtocol.openaiCompatible,
          authMethod: ProviderAuthMethod.external,
          defaultModel: 'gpt-5.4',
          status: InstanceStatus.needsAuth,
          isDefault: true,
          configRevision: 1,
          credentialRevision: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      final setup = service.setupStatus();
      expect(setup.hasProvider, isTrue);
      final runtime = service.runtimeCheck();
      expect(runtime.runtimeReady, isFalse);
      expect(runtime.reason, anyOf(contains('Sign in'), contains('missing')));
    },
  );

  test(
    'non-default instance is never silently selected (fail-closed)',
    () async {
      // A ready instance that is NOT the default must not be picked up by
      // implicit routing/readiness (Plan 29 §3.10, criterion 13/24).
      repo.createInstance(
        ProviderInstance(
          id: 'inst-no-default',
          templateId: 'openai',
          displayName: 'OpenAI (not default)',
          protocol: ProviderProtocol.openaiCompatible,
          authMethod: ProviderAuthMethod.apiKey,
          defaultModel: 'gpt-4o',
          status: InstanceStatus.ready,
          isDefault: false,
          configRevision: 1,
          credentialRevision: 1,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        ),
      );
      await secretStore.write(
        'inst-no-default',
        SecretRecord(
          instanceId: 'inst-no-default',
          apiKey: 'sk-test',
          authMethod: ProviderAuthMethod.apiKey,
        ),
      );
      final result = service.runtimeCheck();
      // No default set → readiness reports no usable provider.
      expect(result.runtimeReady, isFalse);
      expect(result.hasProvider, isFalse);
    },
  );
}
