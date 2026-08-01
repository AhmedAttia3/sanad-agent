import 'dart:async';

import 'package:sanad_client/features/conversations/data/persistence/conversation_cache_persistor.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_draft.dart';
import 'package:sanad_client/features/conversations/domain/models/device_conversation_cache_snapshot.dart';
import 'package:sanad_client/features/conversations/domain/models/device_conversation_context.dart';
import 'package:sanad_client/features/conversations/domain/repositories/conversation_cache_persistence.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

/// In-memory fake persistence backend for testing recovery.
class _FakePersistence implements ConversationCachePersistence {
  DeviceConversationCacheSnapshot stored = DeviceConversationCacheSnapshot.empty();
  Completer<void>? nextSaveBlock;

  @override
  Future<DeviceConversationCacheSnapshot> load() async => stored;

  @override
  Future<void> save(DeviceConversationCacheSnapshot snapshot) async {
    final block = nextSaveBlock;
    nextSaveBlock = null;
    if (block != null) await block.future;
    stored = snapshot;
  }

  @override
  Future<void> clearDevice(String deviceId) async {
    final contexts = Map<String, DeviceConversationContext>.from(stored.contexts);
    contexts.remove(deviceId);
    stored = DeviceConversationCacheSnapshot(
      activeDeviceId: stored.activeDeviceId == deviceId ? null : stored.activeDeviceId,
      contexts: contexts,
      sessionDrafts: Map.fromEntries(
        stored.sessionDrafts.entries.where((e) => !e.key.startsWith('$deviceId|')),
      ),
    );
  }

  @override
  Future<void> clearCloudUserScope(Set<String> cloudDeviceIds) async {
    for (final id in cloudDeviceIds) {
      await clearDevice(id);
    }
  }

  @override
  Future<void> clearAll() async {
    stored = DeviceConversationCacheSnapshot.empty();
  }
}

void main() {
  group('ConversationCachePersistor', () {
    test('hydrate restores active device, contexts, and drafts from persistence', () async {
      final fake = _FakePersistence();
      fake.stored = DeviceConversationCacheSnapshot(
        activeDeviceId: 'device-1',
        contexts: {'device-1': DeviceConversationContext.empty()},
        sessionDrafts: {
          DeviceConversationCacheSnapshot.sessionDraftKey('device-1', 's-1'): ConversationDraft(
            text: 'draft text',
            workspaceId: null,
            providerId: null,
            model: null,
            thinkingMode: null,
            permissionMode: null,
            updatedAt: DateTime.utc(2026, 7, 13),
          ),
        },
      );

      final store = ConversationCacheStore();
      final persistor = ConversationCachePersistor(
        store: store,
        persistence: fake,
        debounceDuration: const Duration(milliseconds: 10),
      );
      await persistor.hydrate();

      expect(store.activeDeviceId, 'device-1');
      expect(store.snapshot.contexts.keys, contains('device-1'));
      expect(
        store.sessionDraft('device-1', 's-1')?.text,
        'draft text',
      );

      store.dispose();
      await persistor.dispose();
    });

    test('debounced save persists after the debounce window', () async {
      final fake = _FakePersistence();
      final store = ConversationCacheStore();
      final persistor = ConversationCachePersistor(
        store: store,
        persistence: fake,
        debounceDuration: const Duration(milliseconds: 20),
      );
      await persistor.hydrate();

      store.setActiveDevice('device-2');
      // Before debounce fires, nothing is saved.
      await Future<void>.delayed(const Duration(milliseconds: 5));
      expect(fake.stored.activeDeviceId, isNull);

      // After debounce, the snapshot is persisted.
      await Future<void>.delayed(const Duration(milliseconds: 40));
      expect(fake.stored.activeDeviceId, 'device-2');

      store.dispose();
      await persistor.dispose();
    });

    test('flush writes immediately without waiting for debounce', () async {
      final fake = _FakePersistence();
      final store = ConversationCacheStore();
      final persistor = ConversationCachePersistor(
        store: store,
        persistence: fake,
        debounceDuration: const Duration(seconds: 5),
      );
      await persistor.hydrate();

      store.setActiveDevice('device-immediate');
      await persistor.flush();
      expect(fake.stored.activeDeviceId, 'device-immediate');

      store.dispose();
      await persistor.dispose();
    });

    test('overlapping flushes serialize without losing the newest snapshot', () async {
      final fake = _FakePersistence();
      final store = ConversationCacheStore();
      final persistor = ConversationCachePersistor(
        store: store,
        persistence: fake,
        debounceDuration: const Duration(seconds: 5),
      );
      await persistor.hydrate();

      store.setActiveDevice('device-old');
      final block = Completer<void>();
      fake.nextSaveBlock = block;
      final firstFlush = persistor.flush();
      await Future<void>.delayed(Duration.zero);
      store.setActiveDevice('device-new');
      final secondFlush = persistor.flush();
      block.complete();
      await Future.wait([firstFlush, secondFlush]);

      expect(fake.stored.activeDeviceId, 'device-new');

      store.dispose();
      await persistor.dispose();
    });

    test('cold start: memory snapshot shows persisted data before any remote call', () async {
      // This simulates a restart: the persisted snapshot must be visible
      // immediately after hydrate, without any refresh.
      final fake = _FakePersistence();
      fake.stored = DeviceConversationCacheSnapshot(
        activeDeviceId: 'device-cold',
        contexts: {'device-cold': DeviceConversationContext.empty()},
        sessionDrafts: {},
      );
      final store = ConversationCacheStore();
      final persistor = ConversationCachePersistor(
        store: store,
        persistence: fake,
      );
      await persistor.hydrate();

      // The store snapshot must already reflect the cold-start data.
      expect(store.snapshot.activeDeviceId, 'device-cold');
      final sidebar = store.sidebarSnapshotFor('device-cold');
      expect(sidebar, isNotNull);
      expect(sidebar!.deviceId, 'device-cold');

      store.dispose();
      await persistor.dispose();
    });
  });
}
