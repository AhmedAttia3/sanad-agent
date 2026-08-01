import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/data/repositories/conversation_cache_repository.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_resource_state.dart';
import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:sanad_client/features/conversations/domain/models/session_query.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_sidebar_cubit.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

import '../../helpers/fake_conversation_repository.dart';

/// Session sidebar pagination, live ordering, and section action tests.
///
/// Verifies:
/// - Lazy first-page fetch for unscoped section via
///   [loadUnscopedConversationsIfNeeded].
/// - [loadMore] delegates to the repository with the correct section key.
/// - Live ordering: canonical session events reorder the sidebar snapshot.
void main() {
  late ConversationCacheStore store;
  late FakeConversationRepository transport;
  late ConversationCacheRepository repository;
  late SessionSidebarCubit cubit;

  final device = DeviceConfig(id: 'device-1', name: 'Sanad Desktop', isOnline: true);
  final workspace = DeviceWorkspace(id: 'ws-1', name: 'Project A', path: '/tmp/a');
  final session1 = Session(
    id: 'session-1',
    title: 'Alpha',
    deviceId: device.id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
    lastMessageAt: DateTime(2026, 1, 1),
  );
  final session2 = Session(
    id: 'session-2',
    title: 'Beta',
    deviceId: device.id,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
    lastMessageAt: DateTime(2026, 1, 2),
  );

  setUp(() {
    store = ConversationCacheStore();
    transport = FakeConversationRepository();
    repository = ConversationCacheRepository(cache: store, transport: transport);
    cubit = SessionSidebarCubit(cacheRepository: repository);
  });

  tearDown(() async {
    await cubit.close();
    await transport.dispose();
  });

  group('loadUnscopedConversationsIfNeeded', () {
    test('triggers refresh when unscoped section is notLoaded', () async {
      store.setActiveDevice(device.id);
      // Seed sessions in the transport so refresh produces data.
      transport.seedSessions(device, [session1, session2]);
      await Future<void>.delayed(Duration.zero);

      // unscoped section is notLoaded initially.
      expect(cubit.state.sectionState(null), ConversationResourceState.notLoaded);

      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      // After refresh the section should be ready with sessions.
      expect(cubit.state.sectionState(null), ConversationResourceState.ready);
      expect(cubit.state.unscopedGroup?.sessions.length, 2);
    });

    test('does nothing when unscoped section is already ready', () async {
      store.setActiveDevice(device.id);
      transport.seedSessions(device, [session1]);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      // First load populates the section.
      expect(cubit.state.sectionState(null), ConversationResourceState.ready);

      // Second call should not re-trigger a refresh — the transport call count
      // would increase only once.
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      // Still ready, sessions unchanged.
      expect(cubit.state.sectionState(null), ConversationResourceState.ready);
      expect(cubit.state.unscopedGroup?.sessions.length, 1);
    });
  });

  test('device refresh skips the first page for a collapsed workspace', () async {
    final collapsed = DeviceWorkspace(id: 'ws-collapsed', name: 'Collapsed', path: '/tmp/collapsed');
    final expanded = DeviceWorkspace(id: 'ws-expanded', name: 'Expanded', path: '/tmp/expanded');
    transport.workspaces.addAll([collapsed, expanded]);
    transport.seedSessions(device, [
      Session(
        id: 'collapsed-session',
        title: 'Collapsed session',
        deviceId: device.id,
        workspaceId: collapsed.id,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
      Session(
        id: 'expanded-session',
        title: 'Expanded session',
        deviceId: device.id,
        workspaceId: expanded.id,
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    ]);
    store.setActiveDevice(device.id);
    store.setWorkspaceExpansion(device.id, collapsed.id, false);

    await repository.refreshDeviceSidebar(device);
    await Future<void>.delayed(Duration.zero);

    final context = store.snapshot.contexts[device.id]!;
    expect(
      context.workspaceConversationPages[collapsed.id]?.state ?? ConversationResourceState.notLoaded,
      ConversationResourceState.notLoaded,
    );
    expect(
      context.workspaceConversationPages[expanded.id]?.state,
      ConversationResourceState.ready,
    );
  });

  test('canonical user message received during refresh survives the stale response', () async {
    final response = Completer<SessionQueryResult>();
    transport.refreshSessionsHandler = (_, __) => response.future;
    store.setActiveDevice(device.id);

    final refresh = cubit.loadUnscopedConversationsIfNeeded(device);
    await Future<void>.delayed(Duration.zero);
    repository.applyUserMessageAccepted(
      device.id,
      session1.id,
      timestamp: DateTime(2026, 1, 3),
    );
    response.complete(SessionQueryResult(sessions: [session1, session2], hasMore: false));
    await refresh;
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.unscopedGroup!.sessions.first.id, session1.id);
    expect(cubit.state.unscopedGroup!.sessions.first.lastMessageAt, DateTime(2026, 1, 3));
  });

  test('workspace created during an older refresh is not removed by its response', () async {
    final response = Completer<List<DeviceWorkspace>>();
    transport.getWorkspacesHandler = (_) => response.future;
    store.setActiveDevice(device.id);

    final refresh = repository.refreshWorkspaces(device);
    await Future<void>.delayed(Duration.zero);
    final created = await repository.createWorkspace(device, path: '/new', name: 'New');
    response.complete(const <DeviceWorkspace>[]);
    await refresh;
    await Future<void>.delayed(Duration.zero);

    expect(created, isNotNull);
    expect(cubit.state.snapshot!.workspaces.map((item) => item.id), contains('/new'));
    expect(cubit.state.workspacesState, ConversationResourceState.ready);
  });

  group('loadMore', () {
    test('loadMore for unscoped section delegates to repository and appends', () async {
      store.setActiveDevice(device.id);
      // Seed more sessions than the first page size (6).
      final sessions = List.generate(
        8,
        (i) => Session(
          id: 'sess-$i',
          title: 'Session $i',
          deviceId: device.id,
          createdAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          updatedAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          lastMessageAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
        ),
      );
      transport.seedSessions(device, sessions);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      // First page has up to 6 sessions.
      expect(cubit.state.unscopedGroup?.sessions.length, 6);
      expect(cubit.state.unscopedGroup?.hasMore, isTrue);

      // Load more.
      await cubit.loadMore(device, workspaceId: null);
      await Future<void>.delayed(Duration.zero);

      // Remaining sessions appended.
      expect(cubit.state.unscopedGroup?.sessions.length, 8);
      expect(cubit.state.unscopedGroup?.hasMore, isFalse);
    });

    test('loadMore for workspace section delegates to repository and appends', () async {
      store.setActiveDevice(device.id);
      store.applyWorkspacesRefreshed(device.id, [workspace], generation: store.advanceWorkspacesGeneration(device.id));
      final sessions = List.generate(
        8,
        (i) => Session(
          id: 'ws-sess-$i',
          title: 'WS Session $i',
          deviceId: device.id,
          workspaceId: workspace.id,
          createdAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          updatedAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          lastMessageAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
        ),
      );
      transport.seedSessions(device, sessions);
      await cubit.loadWorkspaceConversationsIfNeeded(device, workspace.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.workspaceGroups.first.sessions.length, 6);
      expect(cubit.state.workspaceGroups.first.hasMore, isTrue);

      await cubit.loadMore(device, workspaceId: workspace.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.workspaceGroups.first.sessions.length, 8);
    });
  });

  group('live ordering', () {
    test('bumped session moves to top within its section', () async {
      store.setActiveDevice(device.id);
      transport.seedSessions(device, [session1, session2]);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      // session2 has later lastMessageAt → should be first.
      expect(cubit.state.unscopedGroup!.sessions.first.id, 'session-2');

      // Bump session1 with a new timestamp.
      repository.applyUserMessageAccepted(
        device.id,
        'session-1',
        timestamp: DateTime(2026, 1, 3),
      );
      await Future<void>.delayed(Duration.zero);

      // session1 now moves to the top.
      expect(cubit.state.unscopedGroup!.sessions.first.id, 'session-1');
    });

    test('deleted session is removed from sidebar snapshot', () async {
      store.setActiveDevice(device.id);
      transport.seedSessions(device, [session1, session2]);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unscopedGroup!.sessions.length, 2);

      repository.applySessionDeleted(device.id, 'session-1');
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unscopedGroup!.sessions.length, 1);
      expect(cubit.state.unscopedGroup!.sessions.first.id, 'session-2');
    });

    test('created session appears in correct section', () async {
      store.setActiveDevice(device.id);
      transport.seedSessions(device, [session1]);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unscopedGroup!.sessions.length, 1);

      repository.applySessionCreated(device.id, session2);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.unscopedGroup!.sessions.length, 2);
    });
  });

  group('loadingMoreSections', () {
    test('loadingMoreSections reflects in-flight load more', () async {
      store.setActiveDevice(device.id);
      // Seed 8 sessions so the first page (limit 6) has hasMore = true.
      final sessions = List.generate(
        8,
        (i) => Session(
          id: 'sess-$i',
          title: 'Sess $i',
          deviceId: device.id,
          createdAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          updatedAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          lastMessageAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
        ),
      );
      transport.seedSessions(device, sessions);
      await cubit.loadUnscopedConversationsIfNeeded(device);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSectionLoadingMore(null), isFalse);
      expect(cubit.state.loadingMoreSections, isEmpty);

      // Mark load-more as in-flight via the store.
      store.setSectionLoadMoreInProgress(device.id, null);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSectionLoadingMore(null), isTrue);
    });

    test('loadingMoreSections per-workspace is independent', () async {
      store.setActiveDevice(device.id);
      store.applyWorkspacesRefreshed(device.id, [workspace], generation: store.advanceWorkspacesGeneration(device.id));
      // Seed 8 sessions so hasMore = true after first page.
      final wsSessions = List.generate(
        8,
        (i) => Session(
          id: 'ws-sess-$i',
          title: 'WS $i',
          deviceId: device.id,
          workspaceId: workspace.id,
          createdAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          updatedAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
          lastMessageAt: DateTime(2026, 1, 1).subtract(Duration(hours: i)),
        ),
      );
      transport.seedSessions(device, wsSessions);
      await cubit.loadWorkspaceConversationsIfNeeded(device, workspace.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSectionLoadingMore(null), isFalse);
      expect(cubit.state.isSectionLoadingMore(workspace.id), isFalse);

      store.setSectionLoadMoreInProgress(device.id, workspace.id);
      await Future<void>.delayed(Duration.zero);

      expect(cubit.state.isSectionLoadingMore(null), isFalse);
      expect(cubit.state.isSectionLoadingMore(workspace.id), isTrue);
    });
  });
}
