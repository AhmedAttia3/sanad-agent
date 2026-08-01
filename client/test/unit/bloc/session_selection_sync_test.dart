/// Regression tests for the "next message creates a new session" bug and the
/// unified first-send session-creation path.
///
/// Background: [SessionMessagesCubit.sendMessage] locally creates a session
/// whenever `state.activeSessionId` is null — with or without a workspace.
/// If it did not also sync [SessionCubit.state.selectedSession] immediately,
/// the stream listeners in [SessionMessagesCubit] (which derive
/// `activeSessionId` via `_selectedSessionBelongsToCurrentClient`) would clear
/// their own `activeSessionId` before the remote `session_created` event
/// arrived, so the *next* `sendMessage` would see a null `activeSessionId`
/// again and create a brand-new session instead of continuing on the same
/// conversation. This was especially destructive for `codex_responses`-protocol
/// providers that rely on `previous_response_id` server-side continuity.
///
/// The unified path additionally guarantees that a first send without a
/// workspace leaves the New Conversation view: the session is created eagerly
/// and `selectedSession`/`activeSessionId` are set immediately, instead of the
/// removed deferred daemon-side draft creation path.
///
/// Exit criterion: `fvm flutter test` passes.
library;

import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_cubit.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_messages_cubit.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_conversation_repository.dart';
import '../../helpers/fake_device_preferences_repository.dart';
import '../../helpers/fake_device_repository.dart';
import '../../helpers/fake_socket.dart';

void main() {
  const workspace = DeviceWorkspace(id: 'workspace-1', name: 'repo', path: '/repo');

  late FakeSanadSocketService socket;
  late FakeDeviceRepository agentRepository;
  late FakeDeviceClientRegistry agentClientRegistry;
  late TestDeviceCubit agentCubit;
  late FakeConversationRepository conversationRepository;
  late SessionCubit sessionCubit;
  late SessionMessagesCubit messagesCubit;

  late DeviceConfig agent;

  setUp(() {
    socket = FakeSanadSocketService();
    agentRepository = FakeDeviceRepository();
    agentClientRegistry = FakeDeviceClientRegistry();
    agentCubit = TestDeviceCubit(
      socketService: socket,
      agentRepository: agentRepository,
      agentClientRegistry: agentClientRegistry,
    );
    conversationRepository = FakeConversationRepository();
    agent = DeviceConfig(id: 'agent-sync-1', name: 'SanadAgent', isOnline: true);
    agentRepository.seedAgents([agent], activeAgentId: agent.id);
    socket.setConnected(true);
    conversationRepository.transportReady = true;

    sessionCubit = SessionCubit(
      agentCubit: agentCubit,
      socketService: socket,
      conversationRepository: conversationRepository,
    );
    messagesCubit = SessionMessagesCubit(
      agentCubit: agentCubit,
      sessionCubit: sessionCubit,
      conversationRepository: conversationRepository,
      preferencesRepository: FakeDevicePreferencesRepository(),
    );
  });

  tearDown(() async {
    await messagesCubit.close();
    await sessionCubit.close();
    await agentCubit.close();
    await conversationRepository.dispose();
    socket.dispose();
  });

  group('SessionCubit.markSessionSelectedSync', () {
    test('emits the session as selected without switching agents', () async {
      agentCubit.emitState(DeviceActive(activeAgent: agent, agents: [agent]));
      await Future<void>.delayed(Duration.zero);

      final agentsBeforeSwitch = agentCubit.state;

      final fresh = Session(
        id: 'fresh-local',
        title: 'New chat',
        deviceId: agent.id,
        createdAt: DateTime(2026, 1, 3),
        updatedAt: DateTime(2026, 1, 3),
      );

      sessionCubit.markSessionSelectedSync(fresh);
      await Future<void>.delayed(Duration.zero);

      expect(sessionCubit.state.selectedSession?.id, fresh.id);
      expect(
        agentCubit.state,
        same(agentsBeforeSwitch),
        reason: 'markSessionSelectedSync must NOT trigger agentCubit.switchAgent',
      );
    });

    test('is idempotent: a re-invocation for the already-selected session does nothing', () async {
      agentCubit.emitState(DeviceActive(activeAgent: agent, agents: [agent]));
      await Future<void>.delayed(Duration.zero);

      final session = Session(
        id: 'idempotent-session',
        title: 'Same chat',
        deviceId: agent.id,
        createdAt: DateTime(2026, 1, 4),
        updatedAt: DateTime(2026, 1, 4),
      );
      sessionCubit.markSessionSelectedSync(session);
      final firstSelected = sessionCubit.state.selectedSession;
      sessionCubit.markSessionSelectedSync(session);

      expect(sessionCubit.state.selectedSession, same(firstSelected));
    });
  });

  group('SessionMessagesCubit.sendMessage session continuity', () {
    test('sending a second message right after the first in a fresh window does NOT '
        'create a second session', () async {
      agentCubit.emitState(DeviceActive(activeAgent: agent, agents: [agent]));
      await Future<void>.delayed(Duration.zero);

      // Indirectly trigger the workspace-required flow by seeding a workspace and
      // relying on the absence of `requiresWorkspace` (no capabilities store) so
      // that sendMessage proceeds. The cubit starts with no activeSessionId.
      conversationRepository.workspaces.add(workspace);
      // Select the workspace to satisfy sendMessage's workspace requirement.
      messagesCubit.selectWorkspace(workspace);
      await Future<void>.delayed(Duration.zero);

      expect(messagesCubit.state.activeSessionId, isNull);

      // First message in the fresh window: no active session → createSession.
      await messagesCubit.sendMessage('Hello Sanad');
      await Future<void>.delayed(Duration.zero);

      expect(
        conversationRepository.createdSessionRequests.length,
        1,
        reason: 'first message must create exactly one session',
      );
      final firstSessionId = conversationRepository.createdSessionRequests.single['workspace_id'];
      expect(firstSessionId, workspace.id);

      final createdSessionId = 'session-${conversationRepository.createdSessionRequests.length}';
      expect(
        messagesCubit.state.activeSessionId,
        createdSessionId,
        reason: 'activeSessionId must point to the freshly created session',
      );
      expect(
        sessionCubit.state.selectedSession?.id,
        createdSessionId,
        reason: 'SessionCubit.selectedSession must be synced to the new session',
      );

      // Second message in the SAME window: must reuse the active session, NOT
      // create another one. Without the fix, selectedSession would be null or
      // unmatched and activeSessionId would be cleared by the stream listeners.
      await messagesCubit.sendMessage('Follow up');
      await Future<void>.delayed(Duration.zero);

      expect(
        conversationRepository.createdSessionRequests.length,
        1,
        reason: 'second message MUST NOT create a second session',
      );
      expect(
        conversationRepository.sentMessageRequests.where((r) => r['message'] == 'Follow up').single['session_id'],
        createdSessionId,
        reason: 'follow-up message must be sent on the same session id',
      );
    });

    test('first message WITHOUT a workspace creates the session eagerly and '
        'navigates to it (unified session-creation path)', () async {
      agentCubit.emitState(DeviceActive(activeAgent: agent, agents: [agent]));
      await Future<void>.delayed(Duration.zero);

      // No workspace selected: the unified path must still create the session
      // eagerly instead of relying on deferred daemon-side draft creation.
      expect(messagesCubit.state.activeSessionId, isNull);

      await messagesCubit.sendMessage('Hello Sanad without workspace');
      await Future<void>.delayed(Duration.zero);

      expect(
        conversationRepository.createdSessionRequests.length,
        1,
        reason: 'first message must eagerly create exactly one session',
      );
      expect(
        conversationRepository.createdSessionRequests.single['workspace_id'],
        isNull,
        reason: 'session is created without a workspace binding',
      );

      final createdSessionId = 'session-${conversationRepository.createdSessionRequests.length}';
      expect(
        messagesCubit.state.activeSessionId,
        createdSessionId,
        reason: 'activeSessionId must leave the New Conversation view',
      );
      expect(
        sessionCubit.state.selectedSession?.id,
        createdSessionId,
        reason: 'SessionCubit.selectedSession must drive navigation',
      );
      expect(
        conversationRepository.sentMessageRequests.single['session_id'],
        createdSessionId,
        reason: 'the first message is sent on the freshly created session',
      );

      // A follow-up message must continue on the same session.
      await messagesCubit.sendMessage('Follow up');
      await Future<void>.delayed(Duration.zero);

      expect(
        conversationRepository.createdSessionRequests.length,
        1,
        reason: 'follow-up message MUST NOT create another session',
      );
    });
  });
}
