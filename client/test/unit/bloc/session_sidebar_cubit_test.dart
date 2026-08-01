import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/data/repositories/conversation_cache_repository.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_resource_state.dart';
import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_sidebar_cubit.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_sidebar_state.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

import '../../helpers/fake_conversation_repository.dart';

/// Session sidebar projection tests: verify the presentation contract between
/// [SessionSidebarCubit] and [ConversationCacheRepository].
///
/// These tests assert that the sidebar state is a pure projection of the cache
/// store snapshot and that user intents are correctly delegated to the
/// repository. The cubit must never own cache maps, cursors, or drafts.
void main() {
  late ConversationCacheStore store;
  late FakeConversationRepository transport;
  late ConversationCacheRepository repository;
  late SessionSidebarCubit cubit;

  final device = DeviceConfig(id: 'device-1', name: 'Sanad Desktop', isOnline: true);
  final session1 = Session(
    id: 'session-1',
    title: 'Alpha',
    deviceId: device.id,
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );
  final session2 = Session(
    id: 'session-2',
    title: 'Beta',
    deviceId: device.id,
    createdAt: DateTime(2026, 1, 2),
    updatedAt: DateTime(2026, 1, 2),
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

  test('initial state has no active device', () {
    expect(cubit.state.activeDeviceId, isNull);
    expect(cubit.state.snapshot, isNull);
    // No active device means no loading gate; the widget shows "No device selected".
    expect(cubit.state.showInitialLoading, isFalse);
  });

  test('selecting a device projects the sidebar snapshot from cache', () async {
    store.setActiveDevice(device.id);
    store.applySessionCreated(device.id, session1);
    store.applySessionCreated(device.id, session2);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.activeDeviceId, device.id);
    expect(cubit.state.snapshot, isNotNull);
    // Both sessions are unscoped → appear in the unscoped group.
    final unscoped = cubit.state.unscopedGroup;
    expect(unscoped, isNotNull);
    expect(unscoped!.sessions.length, 2);
    // Sorted by lastMessageAt desc; session2 has a later updatedAt.
    expect(unscoped.sessions.first.id, 'session-2');
  });

  test('switching device clears the previous device snapshot projection', () async {
    final device2 = DeviceConfig(id: 'device-2', name: 'Cloud', isOnline: true);
    store.setActiveDevice(device.id);
    store.applySessionCreated(device.id, session1);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.activeDeviceId, device.id);

    store.setActiveDevice(device2.id);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.activeDeviceId, device2.id);
    // device-2 has no sessions → unscoped group is empty/not loaded.
    expect(cubit.state.unscopedGroup?.sessions, isEmpty);
  });

  test('clearing the active device removes the previous snapshot', () async {
    store.setActiveDevice(device.id);
    store.applySessionCreated(device.id, session1);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.snapshot, isNotNull);

    store.setActiveDevice(null);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.activeDeviceId, isNull);
    expect(cubit.state.snapshot, isNull);
    expect(cubit.state.workspaceGroups, isEmpty);
  });

  test('workspace expansion defaults to expanded and toggles via intent', () async {
    final workspace = DeviceWorkspace(id: 'ws-1', name: 'Project A', path: '/tmp/a');
    store.setActiveDevice(device.id);
    store.applyWorkspacesRefreshed(device.id, [workspace], generation: store.advanceWorkspacesGeneration(device.id));
    await Future<void>.delayed(Duration.zero);

    // Default expanded.
    expect(cubit.state.isWorkspaceExpanded('ws-1'), isTrue);

    // Toggle off.
    cubit.toggleWorkspaceExpansion(device.id, 'ws-1');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isWorkspaceExpanded('ws-1'), isFalse);

    // Toggle back on.
    cubit.toggleWorkspaceExpansion(device.id, 'ws-1');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isWorkspaceExpanded('ws-1'), isTrue);
  });

  test('workspaceGroups getter separates workspace-scoped from unscoped', () async {
    final workspace = DeviceWorkspace(id: 'ws-1', name: 'Project A', path: '/tmp/a');
    store.setActiveDevice(device.id);
    store.applyWorkspacesRefreshed(device.id, [workspace], generation: store.advanceWorkspacesGeneration(device.id));
    // Add a workspace-scoped session.
    final scopedSession = Session(
      id: 'scoped-1',
      title: 'Scoped',
      deviceId: device.id,
      workspaceId: 'ws-1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );
    store.applySessionCreated(device.id, scopedSession);
    store.applySessionCreated(device.id, session1);
    await Future<void>.delayed(Duration.zero);

    final groups = cubit.state.workspaceGroups;
    expect(groups.length, 1);
    expect(groups.first.workspaceId, 'ws-1');
    expect(groups.first.sessions.any((s) => s.id == 'scoped-1'), isTrue);

    final unscoped = cubit.state.unscopedGroup;
    expect(unscoped, isNotNull);
    expect(unscoped!.sessions.any((s) => s.id == 'session-1'), isTrue);
  });

  test('sectionState reflects the cache lifecycle for unscoped section', () async {
    store.setActiveDevice(device.id);
    await Future<void>.delayed(Duration.zero);

    // Before any refresh, section is notLoaded.
    expect(cubit.state.sectionState(null), ConversationResourceState.notLoaded);
  });

  test('showInitialLoading becomes false once cache has usable snapshot', () async {
    store.setActiveDevice(device.id);
    store.applySessionCreated(device.id, session1);
    await Future<void>.delayed(Duration.zero);

    expect(cubit.state.showInitialLoading, isFalse);
  });

  test('closing the cubit cancels subscriptions without throwing', () async {
    store.setActiveDevice(device.id);
    await Future<void>.delayed(Duration.zero);
    await cubit.close();
    // Subsequent store changes should not throw after close.
    store.applySessionCreated(device.id, session1);
  });

  test('SessionSidebarState copyWith preserves all fields correctly', () {
    const state = SessionSidebarState(
      activeDeviceId: 'dev',
      showInitialLoading: false,
    );
    final updated = state.copyWith(isRefreshing: true);
    expect(updated.activeDeviceId, 'dev');
    expect(updated.isRefreshing, isTrue);
    expect(updated.showInitialLoading, isFalse);
  });
}
