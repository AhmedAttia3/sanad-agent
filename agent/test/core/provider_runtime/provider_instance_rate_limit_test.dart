import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';
import 'package:sanad_agent/core/provider_runtime/provider_instance_repository.dart';
import 'package:sanad_agent/core/provider_runtime/provider_instance_service.dart';
import 'package:sanad_agent/core/provider_runtime/provider_protocol_constants.dart';
import 'package:sanad_agent/evolution/db/agent_state_database.dart';
import 'package:sanad_agent/engine/adapters/provider_registry.dart';

void main() {
  late AgentStateDatabase state;
  late ProviderInstanceRepository repo;
  late ProviderInstanceService instanceService;

  setUp(() {
    state = AgentStateDatabase.inMemory();
    repo = ProviderInstanceRepository.fromDatabase(state.db);
    instanceService = ProviderInstanceService(repo);
  });

  tearDown(() => state.dispose());

  group('Plan 30 — rate limit + auto failover storage', () {
    test(
      'new instance defaults to unlimited (rpm=0) and allowAutoFailover=true',
      () {
        final inst = instanceService.create(
          templateId: 'openai',
          displayName: 'OpenAI',
          authMethod: ProviderAuthMethod.apiKey,
        );
        expect(inst.requestsPerMinute, equals(0));
        expect(inst.allowAutoFailover, isTrue);
        expect(inst.isRateLimited, isFalse);
      },
    );

    test('NVIDIA template is unlimited like every other template', () {
      final inst = instanceService.create(
        templateId: 'nvidia',
        displayName: 'NVIDIA NIM',
        authMethod: ProviderAuthMethod.apiKey,
      );
      expect(inst.requestsPerMinute, equals(0));
      expect(inst.isRateLimited, isFalse);
    });

    test('legacy explicit rpm input is normalized to unlimited', () {
      final inst = instanceService.create(
        templateId: 'openai',
        displayName: 'OpenAI',
        authMethod: ProviderAuthMethod.apiKey,
        requestsPerMinute: 20,
      );
      expect(inst.requestsPerMinute, equals(0));
      expect(inst.isRateLimited, isFalse);
    });

    test('allowAutoFailover=false is stored', () {
      final inst = instanceService.create(
        templateId: 'openai',
        displayName: 'OpenAI Personal',
        authMethod: ProviderAuthMethod.apiKey,
        allowAutoFailover: false,
      );
      expect(inst.allowAutoFailover, isFalse);
    });

    test('toMap / fromMap round-trips new fields', () {
      final inst = instanceService.create(
        templateId: 'nvidia',
        displayName: 'NIM',
        authMethod: ProviderAuthMethod.apiKey,
        requestsPerMinute: 38,
        allowAutoFailover: false,
      );
      final map = inst.toMap();
      expect(map['requests_per_minute'], equals(0));
      expect(map['allow_auto_failover'], isFalse);
      // Round-trip via DB to exercise the repository row mapping.
      final reloaded = repo.findById(inst.id)!;
      expect(reloaded.requestsPerMinute, equals(0));
      expect(reloaded.allowAutoFailover, isFalse);
    });

    test('updateMetadata keeps legacy rpm input dormant', () {
      final inst = instanceService.create(
        templateId: 'openai',
        displayName: 'OpenAI',
        authMethod: ProviderAuthMethod.apiKey,
      );
      final beforeRev = inst.configRevision;
      final updated = instanceService.updateMetadata(
        inst.id,
        requestsPerMinute: 50,
      );
      expect(updated.requestsPerMinute, equals(0));
      expect(updated.configRevision, equals(beforeRev));
      expect(updated.status, equals(inst.status));
    });

    test('updateMetadata can toggle allowAutoFailover', () {
      final inst = instanceService.create(
        templateId: 'openai',
        displayName: 'OpenAI',
        authMethod: ProviderAuthMethod.apiKey,
      );
      expect(inst.allowAutoFailover, isTrue);
      final updated = instanceService.updateMetadata(
        inst.id,
        allowAutoFailover: false,
      );
      expect(updated.allowAutoFailover, isFalse);
    });

    test('updateMetadata normalizes any legacy rpm value to zero', () {
      final inst = instanceService.create(
        templateId: 'openai',
        displayName: 'OpenAI',
        authMethod: ProviderAuthMethod.apiKey,
      );
      final updated = instanceService.updateMetadata(
        inst.id,
        requestsPerMinute: -1,
      );
      expect(updated.requestsPerMinute, equals(0));
    });

    test('persisted instance survives reload from DB', () {
      instanceService.create(
        templateId: 'nvidia',
        displayName: 'NIM',
        authMethod: ProviderAuthMethod.apiKey,
      );
      final reloaded = repo.findAll().single;
      expect(reloaded.requestsPerMinute, equals(0));
      expect(reloaded.allowAutoFailover, isTrue);
    });
  });

  group('Task 57 — dormant provider rate limits', () {
    test('all templates advertise unlimited', () {
      for (final profile in ProviderRegistry.profiles) {
        expect(
          profile.defaultRequestsPerMinute,
          equals(0),
          reason: '${profile.name} should default to unlimited',
        );
      }
    });

    test('toPublicMap retains the compatibility field with zero', () {
      final nvidia = ProviderRegistry.findByNameOrAlias('nvidia')!;
      final map = nvidia.toPublicMap();
      expect(map['default_requests_per_minute'], equals(0));
    });

    test('database upgrade normalizes existing non-zero limits', () {
      final legacyDb = sqlite3.openInMemory();
      legacyDb.execute('''
        CREATE TABLE provider_instances (
          id TEXT PRIMARY KEY,
          template_id TEXT NOT NULL,
          display_name TEXT NOT NULL,
          display_name_lower TEXT NOT NULL,
          protocol TEXT NOT NULL,
          auth_method TEXT NOT NULL,
          base_url TEXT,
          default_model TEXT,
          status TEXT NOT NULL DEFAULT 'draft',
          is_default INTEGER NOT NULL DEFAULT 0,
          config_revision INTEGER NOT NULL DEFAULT 1,
          credential_revision INTEGER NOT NULL DEFAULT 1,
          requests_per_minute INTEGER NOT NULL DEFAULT 0,
          allow_auto_failover INTEGER NOT NULL DEFAULT 1,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        );
      ''');
      legacyDb.execute('''
        INSERT INTO provider_instances (
          id, template_id, display_name, display_name_lower, protocol,
          auth_method, requests_per_minute, created_at, updated_at
        ) VALUES (
          'legacy', 'nvidia', 'NVIDIA NIM', 'nvidia nim',
          'openai_compatible', 'api_key', 38,
          '2026-01-01T00:00:00Z', '2026-01-01T00:00:00Z'
        );
      ''');

      final migrated = AgentStateDatabase.fromConnection(legacyDb);
      addTearDown(legacyDb.dispose);

      final value = migrated.db.select(
        'SELECT requests_per_minute FROM provider_instances WHERE id = ?',
        ['legacy'],
      ).single['requests_per_minute'];
      expect(value, equals(0));
    });
  });
}
