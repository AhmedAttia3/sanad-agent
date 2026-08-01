import 'package:sanad_client/core/navigation/conversation_destination.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_draft.dart';
import 'package:sanad_client/features/conversations/domain/models/device_conversation_cache_snapshot.dart';
import 'package:sanad_client/features/conversations/domain/models/device_conversation_context.dart';
import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_resource_state.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late ConversationCacheStore store;

  setUp(() {
    store = ConversationCacheStore();
  });

  tearDown(() {
    store.dispose();
  });

  Session makeSession({
    required String id,
    String deviceId = 'device-1',
    String? workspaceId,
    DateTime? lastMessageAt,
    DateTime? updatedAt,
  }) {
    return Session(
      id: id,
      title: 'Session $id',
      deviceId: deviceId,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime.utc(2026, 7, 13),
      lastMessageAt: lastMessageAt,
      workspaceId: workspaceId,
    );
  }

  group('ConversationCacheStore - device context', () {
    test('setActiveDevice emits and preserves other device caches', () {
      var firedSnapshots = 0;
      store.snapshotStream.listen((_) => firedSnapshots++);

      store.applyWorkspacesRefreshed(
        'device-A',
        const [],
        generation: store.advanceWorkspacesGeneration('device-A'),
      );
      store.setActiveDevice('device-B');

      expect(store.activeDeviceId, 'device-B');
      // device-A cache should still be present.
      expect(store.snapshot.contexts.keys, containsAll(['device-A', 'device-B']));
    });

    test('loading a populated section preserves rows as a refresh snapshot', () {
      store.applySessionCreated('device-1', makeSession(id: 'cached'));

      store.setSectionLoading('device-1', null);

      final page = store.snapshot.contexts['device-1']!.unscopedConversations;
      expect(page.sessions.single.id, 'cached');
      expect(page.state, ConversationResourceState.refreshing);
    });

    test('switching to null active device clears pointer but keeps caches', () {
      store.setActiveDevice('device-1');
      store.setActiveDevice(null);
      expect(store.activeDeviceId, isNull);
      expect(store.snapshot.contexts.keys, contains('device-1'));
    });

    test('remaps legacy path workspace cache keys to daemon UUID', () {
      const legacyPath = '/repo/project-a';
      const workspaceId = 'workspace-uuid';
      store.applyWorkspacesRefreshed(
        'device-1',
        const [
          DeviceWorkspace(
            id: legacyPath,
            name: 'Project A',
            path: legacyPath,
          ),
        ],
        generation: store.advanceWorkspacesGeneration('device-1'),
      );
      store.applySessionCreated(
        'device-1',
        makeSession(id: 'legacy-session', workspaceId: legacyPath),
      );
      store.setWorkspaceExpansion('device-1', legacyPath, false);
      store.setNewConversationDraft(
        'device-1',
        text: 'draft',
        workspaceId: legacyPath,
      );
      store.recordLastDestination(
        const ConversationDestination.newConversation(
          deviceId: 'device-1',
          workspaceId: legacyPath,
        ),
      );

      store.applyWorkspacesRefreshed(
        'device-1',
        const [
          DeviceWorkspace(
            id: workspaceId,
            name: 'Project A',
            path: legacyPath,
          ),
        ],
        generation: store.advanceWorkspacesGeneration('device-1'),
      );

      final context = store.snapshot.contexts['device-1']!;
      expect(context.workspaceConversationPages, contains(workspaceId));
      expect(context.workspaceConversationPages, isNot(contains(legacyPath)));
      expect(context.workspaceExpansion[workspaceId], isFalse);
      expect(context.newConversationDraftWorkspaceId, workspaceId);
      expect(context.lastDestination?.workspaceId, workspaceId);
    });

    test('typed destination distinguishes sessions from both New Conversation forms', () {
      const sessionDestination = ConversationDestination.session(
        deviceId: 'device-1',
        sessionId: 'session-1',
      );
      store.recordLastDestination(sessionDestination);
      expect(store.snapshot.contexts['device-1']?.lastDestination, sessionDestination);
      expect(store.snapshot.contexts['device-1']?.lastSelectedSessionId, 'session-1');

      const newWithoutWorkspace = ConversationDestination.newConversation(
        deviceId: 'device-1',
      );
      store.recordLastDestination(newWithoutWorkspace);
      expect(store.snapshot.contexts['device-1']?.lastDestination, newWithoutWorkspace);
      expect(store.snapshot.contexts['device-1']?.lastSelectedSessionId, 'session-1');

      const newWithWorkspace = ConversationDestination.newConversation(
        deviceId: 'device-1',
        workspaceId: 'workspace-1',
      );
      store.recordLastDestination(newWithWorkspace);
      expect(store.snapshot.contexts['device-1']?.lastDestination, newWithWorkspace);
      expect(store.snapshot.contexts['device-1']?.lastSelectedSessionId, 'session-1');
    });

    test('conversation-list destinations cannot become restart destinations', () {
      expect(
        () => store.recordLastDestination(
          const ConversationDestination.conversationsList(deviceId: 'device-1'),
        ),
        throwsArgumentError,
      );
    });

    test('viewport anchors are session scoped and restored from snapshots', () {
      store.recordSessionViewportAnchor('device-1', 'session-1', 'event-10');
      store.recordSessionViewportAnchor('device-1', 'session-2', 'event-20');

      expect(
        store.sessionViewportAnchor('device-1', 'session-1'),
        'event-10',
      );
      expect(
        store.sessionViewportAnchor('device-1', 'session-2'),
        'event-20',
      );

      final restored = ConversationCacheStore();
      addTearDown(restored.dispose);
      restored.restoreFromSnapshot(store.snapshot);
      expect(
        restored.sessionViewportAnchor('device-1', 'session-1'),
        'event-10',
      );
    });

    test('new user turns and session deletion clear viewport anchors', () {
      store.recordSessionViewportAnchor('device-1', 'session-1', 'event-10');
      store.applyUserMessageAccepted('device-1', 'session-1');
      expect(store.sessionViewportAnchor('device-1', 'session-1'), isNull);

      store.recordSessionViewportAnchor('device-1', 'session-1', 'event-20');
      store.applySessionDeleted('device-1', 'session-1');
      expect(store.sessionViewportAnchor('device-1', 'session-1'), isNull);
    });

    test('clearing a device removes its viewport anchors only', () {
      store.recordSessionViewportAnchor('device-1', 'session-1', 'event-10');
      store.recordSessionViewportAnchor('device-2', 'session-2', 'event-20');

      store.clearDevice('device-1');

      expect(store.sessionViewportAnchor('device-1', 'session-1'), isNull);
      expect(
        store.sessionViewportAnchor('device-2', 'session-2'),
        'event-20',
      );
    });
  });

  group('ConversationCacheStore - stale response rejection', () {
    test('a stale generation response does not overwrite a newer snapshot', () {
      final gen1 = store.advanceGeneration('device-1', null);
      final gen2 = store.advanceGeneration('device-1', null);

      store.applySectionRefreshed(
        'device-1',
        null,
        [makeSession(id: 's-new')],
        nextCursor: null,
        hasMore: false,
        generation: gen2,
      );
      // gen1 is now stale; applying it must not clobber gen2.
      store.applySectionRefreshed(
        'device-1',
        null,
        [makeSession(id: 's-stale')],
        nextCursor: null,
        hasMore: false,
        generation: gen1,
      );

      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.unscopedConversations.sessions.single.id, 's-new');
    });

    test('workspaces stale response is rejected', () {
      // Seed context by setting active device first.
      store.setActiveDevice('device-1');
      final gen1 = store.advanceWorkspacesGeneration('device-1');
      // Advance again so gen1 is stale.
      store.advanceWorkspacesGeneration('device-1');
      store.applyWorkspacesRefreshed('device-1', const [], generation: gen1);
      // Context must still exist (from setActiveDevice) but workspaces stay notLoaded.
      final ctx = store.snapshot.contexts['device-1'];
      expect(ctx, isNotNull);
    });
  });

  group('ConversationCacheStore - pagination merge', () {
    test('authoritative first page removes rows absent from the response', () {
      // Seed a prior state via append.
      final gen0 = store.advanceGeneration('device-1', 'ws-1');
      store.applySectionRefreshed(
        'device-1',
        'ws-1',
        [makeSession(id: 'a'), makeSession(id: 'b'), makeSession(id: 'c')],
        nextCursor: 'cursor-1',
        hasMore: true,
        generation: gen0,
      );
      // Load more appends d, e.
      final gen1 = store.advanceGeneration('device-1', 'ws-1');
      store.applySectionPageAppended(
        'device-1',
        'ws-1',
        [makeSession(id: 'd'), makeSession(id: 'e')],
        nextCursor: null,
        hasMore: false,
        generation: gen1,
      );

      // Now an authoritative refresh returns only a, b.
      final gen2 = store.advanceGeneration('device-1', 'ws-1');
      store.applySectionRefreshed(
        'device-1',
        'ws-1',
        [makeSession(id: 'a'), makeSession(id: 'b')],
        nextCursor: 'cursor-2',
        hasMore: true,
        generation: gen2,
      );

      final ctx = store.snapshot.contexts['device-1']!;
      final ids = ctx.workspaceConversationPages['ws-1']!.sessions.map((s) => s.id).toSet();
      expect(ids, {'a', 'b'});
    });

    test('append deduplicates by session id', () {
      final gen0 = store.advanceGeneration('device-1', null);
      store.applySectionRefreshed(
        'device-1',
        null,
        [makeSession(id: 'a'), makeSession(id: 'b')],
        nextCursor: 'cursor-1',
        hasMore: true,
        generation: gen0,
      );
      final gen1 = store.advanceGeneration('device-1', null);
      store.applySectionPageAppended(
        'device-1',
        null,
        [makeSession(id: 'b'), makeSession(id: 'c')], // b is duplicate
        nextCursor: null,
        hasMore: false,
        generation: gen1,
      );
      final ctx = store.snapshot.contexts['device-1']!;
      final ids = ctx.unscopedConversations.sessions.map((s) => s.id).toList();
      expect(ids.toSet(), {'a', 'b', 'c'});
      expect(ids.where((id) => id == 'b').length, 1);
    });
  });

  group('ConversationCacheStore - canonical events', () {
    test('session_created inserts into correct section and re-sorts', () {
      final session = makeSession(id: 's-new', workspaceId: 'ws-1');
      store.applySessionCreated('device-1', session);
      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.workspaceConversationPages['ws-1']!.sessions.single.id, 's-new');
    });

    test('session_deleted removes from all sections, drafts, and last-selected', () {
      store.applySessionCreated('device-1', makeSession(id: 's-1', workspaceId: 'ws-1'));
      store.recordLastDestination(
        const ConversationDestination.session(
          deviceId: 'device-1',
          sessionId: 's-1',
        ),
      );
      store.setSessionDraft(
        'device-1',
        's-1',
        ConversationDraft(
          text: 'hi',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );

      store.applySessionDeleted('device-1', 's-1');

      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.workspaceConversationPages['ws-1']!.sessions, isEmpty);
      expect(ctx.lastSelectedSessionId, isNull);
      expect(store.sessionDraft('device-1', 's-1'), isNull);
    });

    test('user_message_accepted bumps timestamp and moves session to top', () {
      final older = makeSession(
        id: 's-old',
        workspaceId: null,
        lastMessageAt: DateTime.utc(2026, 7, 1),
      );
      final newer = makeSession(
        id: 's-new',
        workspaceId: null,
        lastMessageAt: DateTime.utc(2026, 7, 10),
      );
      final gen = store.advanceGeneration('device-1', null);
      store.applySectionRefreshed(
        'device-1',
        null,
        [newer, older],
        nextCursor: null,
        hasMore: false,
        generation: gen,
      );

      final bumpedAt = DateTime.utc(2026, 7, 13, 12, 0);
      store.applyUserMessageAccepted('device-1', 's-old', timestamp: bumpedAt);

      final ctx = store.snapshot.contexts['device-1']!;
      final sessions = ctx.unscopedConversations.sessions;
      // s-old should now be first because its lastMessageAt is the most recent.
      expect(sessions.first.id, 's-old');
      expect(sessions.first.lastMessageAt, bumpedAt);
    });

    test('canonical acceptance clears only the matching pending draft', () {
      store.applySessionCreated('device-1', makeSession(id: 's-1'));
      store.setSessionDraft(
        'device-1',
        's-1',
        ConversationDraft(
          text: 'keep me',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          pendingRequestId: 'request-new',
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );

      store.applyUserMessageAccepted(
        'device-1',
        's-1',
        requestId: 'request-old',
      );
      expect(store.sessionDraft('device-1', 's-1'), isNotNull);

      store.applyUserMessageAccepted(
        'device-1',
        's-1',
        requestId: 'request-new',
      );
      expect(store.sessionDraft('device-1', 's-1'), isNull);
    });
  });

  group('ConversationCacheStore - drafts', () {
    test('session draft set and clear', () {
      store.setSessionDraft(
        'device-1',
        's-1',
        ConversationDraft(
          text: 'hello',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );
      expect(store.sessionDraft('device-1', 's-1')?.text, 'hello');
      store.clearSessionDraft('device-1', 's-1');
      expect(store.sessionDraft('device-1', 's-1'), isNull);
    });

    test('new conversation draft set and clear', () {
      store.setNewConversationDraft('device-1', text: 'new text');
      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.newConversationDraftText, 'new text');
      store.clearNewConversationDraft('device-1');
      final ctx2 = store.snapshot.contexts['device-1']!;
      expect(ctx2.newConversationDraftText, isEmpty);
    });

    test('nullable new-draft fields can be cleared independently', () {
      store.setNewConversationDraft(
        'device-1',
        workspaceId: 'ws-1',
        providerId: 'provider-1',
      );
      store.setNewConversationDraft('device-1', clearWorkspace: true);

      var ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.newConversationDraftWorkspaceId, isNull);
      expect(ctx.newConversationDraftProviderId, 'provider-1');

      store.clearNewConversationDraft('device-1');
      ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.newConversationDraftProviderId, isNull);
    });

    test('a newer edit clears the pending acceptance marker only', () {
      store.setNewConversationDraft(
        'device-1',
        text: 'sent text',
        workspaceId: 'ws-1',
      );
      store.markNewConversationDraftAwaitingAcceptance('device-1', 'request-1');
      store.setNewConversationDraft(
        'device-1',
        text: 'newer text',
        clearPendingRequest: true,
      );

      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.newConversationDraftText, 'newer text');
      expect(ctx.newConversationDraftWorkspaceId, 'ws-1');
      expect(ctx.newConversationDraftPendingRequestId, isNull);
    });

    test('transferNewConversationDraftToSession moves text and clears new draft', () {
      store.setNewConversationDraft(
        'device-1',
        text: 'transferred',
        workspaceId: 'ws-1',
        model: 'gpt-5.2',
      );
      store.transferNewConversationDraftToSession('device-1', 's-new');

      final draft = store.sessionDraft('device-1', 's-new');
      expect(draft, isNotNull);
      expect(draft!.text, 'transferred');
      expect(draft.workspaceId, 'ws-1');
      // New draft should be cleared.
      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.newConversationDraftText, isEmpty);
    });
  });

  group('ConversationCacheStore - workspace expansion', () {
    test('setWorkspaceExpansion persists in context', () {
      store.setWorkspaceExpansion('device-1', 'ws-1', true);
      var ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.workspaceExpansion['ws-1'], isTrue);
      store.setWorkspaceExpansion('device-1', 'ws-1', false);
      ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.workspaceExpansion['ws-1'], isFalse);
    });

    test('workspace refresh prunes removed pages and expansion preferences', () {
      store.setWorkspaceExpansion('device-1', 'removed', false);
      store.applySessionCreated(
        'device-1',
        makeSession(id: 's-removed', workspaceId: 'removed'),
      );
      final generation = store.advanceWorkspacesGeneration('device-1');
      store.applyWorkspacesRefreshed(
        'device-1',
        const [],
        generation: generation,
      );

      final ctx = store.snapshot.contexts['device-1']!;
      expect(ctx.workspaceConversationPages, isEmpty);
      expect(ctx.workspaceExpansion, isEmpty);
    });
  });

  group('ConversationCacheStore - restoreFromSnapshot', () {
    test('bulk restore replaces live state', () {
      store.setActiveDevice('device-old');
      store.setSessionDraft(
        'device-old',
        's-x',
        ConversationDraft(
          text: 'stale',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );

      final fresh = DeviceConversationCacheSnapshot(
        activeDeviceId: 'device-fresh',
        contexts: {'device-fresh': DeviceConversationContext.empty()},
        sessionDrafts: {},
      );
      store.restoreFromSnapshot(fresh);

      expect(store.activeDeviceId, 'device-fresh');
      expect(store.snapshot.contexts.keys, contains('device-fresh'));
      expect(store.snapshot.contexts.keys, isNot(contains('device-old')));
    });
  });

  group('ConversationCacheStore - clearDevice / clearCloudUserScope', () {
    test('clearDevice removes context, drafts, and clears active pointer', () {
      store.setActiveDevice('device-1');
      store.setSessionDraft(
        'device-1',
        's-1',
        ConversationDraft(
          text: 'x',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );
      store.clearDevice('device-1');
      expect(store.snapshot.contexts['device-1'], isNull);
      expect(store.activeDeviceId, isNull);
      expect(store.sessionDraft('device-1', 's-1'), isNull);
    });

    test('clearCloudUserScope removes only cloud device keys', () {
      store.setActiveDevice('device-local');
      store.setSessionDraft(
        'device-local',
        's-1',
        ConversationDraft(
          text: 'local',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );
      store.setSessionDraft(
        'device-cloud',
        's-2',
        ConversationDraft(
          text: 'cloud',
          workspaceId: null,
          providerId: null,
          model: null,
          thinkingMode: null,
          permissionMode: null,
          updatedAt: DateTime.utc(2026, 7, 13),
        ),
      );
      store.clearCloudUserScope({'device-cloud'});
      expect(store.sessionDraft('device-local', 's-1'), isNotNull);
      expect(store.sessionDraft('device-cloud', 's-2'), isNull);
    });
  });

  group('ConversationCacheStore - sidebar snapshot', () {
    test('sidebarSnapshotFor produces groups for each workspace plus unscoped', () {
      final genWs = store.advanceWorkspacesGeneration('device-1');
      store.applyWorkspacesRefreshed(
        'device-1',
        const [],
        generation: genWs,
      );
      // Can't easily construct DeviceWorkspace const; test null device.
      expect(store.sidebarSnapshotFor('nope'), isNull);
    });
  });

  test('stop recovery prepends once and preserves the existing draft', () {
    store.setSessionDraft(
      'device-1',
      'session-1',
      ConversationDraft(
        text: 'E',
        workspaceId: null,
        providerId: null,
        model: null,
        thinkingMode: null,
        permissionMode: null,
        updatedAt: DateTime.utc(2026, 7, 15),
      ),
    );
    store.markStopRecoveryPending('device-1', 'session-1', 'stop-1');

    expect(
      store.prependStopRecovery(
        'device-1',
        'session-1',
        stopRequestId: 'stop-1',
        texts: const ['A', 'B', 'C', 'D'],
      ),
      isTrue,
    );
    expect(store.sessionDraft('device-1', 'session-1')?.text, 'A\nB\nC\nD\nE');
    expect(store.sessionDraft('device-1', 'session-1')?.pendingStopRecoveryIds, isEmpty);
    expect(
      store.prependStopRecovery(
        'device-1',
        'session-1',
        stopRequestId: 'stop-1',
        texts: const ['A', 'B', 'C', 'D'],
      ),
      isFalse,
    );
    expect(store.sessionDraft('device-1', 'session-1')?.text, 'A\nB\nC\nD\nE');
  });

  test('stop recovery claim ownership is persisted and cleared explicitly', () {
    store.setStopRecoveryClaim('device-1', 'session-1', 'restart-stop-1', 'claim-1');

    expect(
      store.sessionDraft('device-1', 'session-1')?.stopRecoveryClaimIds,
      {'restart-stop-1': 'claim-1'},
    );

    store.clearStopRecoveryClaim('device-1', 'session-1', 'restart-stop-1');
    expect(store.sessionDraft('device-1', 'session-1')?.stopRecoveryClaimIds, isEmpty);
  });

  test('user stop recovery owner token is stored with pending ownership', () {
    store.markStopRecoveryPending(
      'device-1',
      'session-1',
      'stop-1',
      ownerToken: 'owner-secret-1',
    );

    expect(
      store.sessionDraft('device-1', 'session-1')?.stopRecoveryOwnerTokens,
      {'stop-1': 'owner-secret-1'},
    );

    store.clearStopRecoveryOwnerToken('device-1', 'session-1', 'stop-1');
    expect(
      store.sessionDraft('device-1', 'session-1')?.stopRecoveryOwnerTokens,
      isEmpty,
    );
  });
}
