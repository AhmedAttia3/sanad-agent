import 'package:sanad_agent/core/di.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/core/models/tool_call.dart';
import 'package:sanad_agent/evolution/db/agent_state_database.dart';
import 'package:sanad_agent/evolution/db/persisted_runtime_state_repository.dart';
import 'package:sanad_agent/evolution/session_manager.dart';
import 'package:sanad_agent/interfaces/runtime/turn_replay_service.dart';
import 'package:test/test.dart';

void main() {
  late AgentStateDatabase state;
  late SessionManager sessions;
  late PersistedRuntimeStateRepository runtime;
  late String sessionId;

  setUp(() async {
    await getIt.reset();
    SessionManager.resetForTesting();
    state = AgentStateDatabase.inMemory();
    getIt.registerSingleton<AgentStateDatabase>(state);
    sessions = SessionManager();
    runtime = PersistedRuntimeStateRepository.fromState(state);
    sessionId = sessions.createSession('model').sessionId;
  });

  tearDown(() async {
    SessionManager.resetForTesting();
    await getIt.reset();
  });

  Message user(String requestId, String text) => Message(
    role: MessageRole.user,
    content: text,
    metadata: {'request_id': requestId},
  );

  test('safe latest turn is resolved and truncated at its user boundary', () {
    sessions.saveSessionHistory(sessionId, [
      user('request-1', 'first'),
      Message(role: MessageRole.assistant, content: 'first answer'),
      user('request-2', 'second'),
      Message(role: MessageRole.assistant, content: 'second answer'),
    ]);
    final service = TurnReplayService(
      sessionManager: sessions,
      persistedState: runtime,
    );

    final inspection = service.inspect(
      sessionId: sessionId,
      targetRequestId: 'request-2',
    );

    expect(inspection.canReplay, isTrue);
    expect(inspection.safety, TurnReplaySafety.safe);
    expect(inspection.requiresConfirmation, isFalse);
    expect(service.truncateAtTarget(inspection), isTrue);
    expect(sessions.getMessages(sessionId).map((message) => message.content), [
      'first',
      'first answer',
    ]);
  });

  test('older user turn is rejected to preserve newer user-owned turns', () {
    sessions.saveSessionHistory(sessionId, [
      user('request-1', 'first'),
      Message(role: MessageRole.assistant, content: 'first answer'),
      user('request-2', 'second'),
    ]);
    final service = TurnReplayService(
      sessionManager: sessions,
      persistedState: runtime,
    );

    final inspection = service.inspect(
      sessionId: sessionId,
      targetRequestId: 'request-1',
    );

    expect(
      inspection.failure,
      TurnReplayInspectionFailure.targetIsNotLatestTurn,
    );
    expect(service.truncateAtTarget(inspection), isFalse);
    expect(sessions.getMessages(sessionId), hasLength(3));
  });

  test('unsafe tool metadata requires confirmation', () {
    sessions.saveSessionHistory(sessionId, [
      user('request-tool', 'change the file'),
      Message(
        role: MessageRole.assistant,
        toolCalls: [
          ToolCall(id: 'tool-1', name: 'file_edit', arguments: const {}),
        ],
      ),
      Message(role: MessageRole.tool, toolCallId: 'tool-1', content: 'done'),
    ]);
    final now = DateTime.now().toUtc();
    runtime.workItems.insertWorkItem(
      SessionWorkItem(
        workItemId: 'work-1',
        sessionId: sessionId,
        requestId: 'request-tool',
        sequence: 1,
        attempt: 0,
        state: SessionWorkState.completed,
        continuationMetadata: const {
          'tool_replay_safety': {'tool-1': false},
        },
        createdAt: now,
        updatedAt: now,
      ),
    );
    final service = TurnReplayService(
      sessionManager: sessions,
      persistedState: runtime,
    );

    final inspection = service.inspect(
      sessionId: sessionId,
      targetRequestId: 'request-tool',
    );

    expect(inspection.safety, TurnReplaySafety.unsafe);
    expect(inspection.requiresConfirmation, isTrue);
  });

  test('missing tool safety metadata is fail-closed as unknown', () {
    sessions.saveSessionHistory(sessionId, [
      user('request-tool', 'use a tool'),
      Message(
        role: MessageRole.assistant,
        toolCalls: [
          ToolCall(id: 'tool-1', name: 'unknown', arguments: const {}),
        ],
      ),
    ]);
    final service = TurnReplayService(
      sessionManager: sessions,
      persistedState: runtime,
    );

    final inspection = service.inspect(
      sessionId: sessionId,
      targetRequestId: 'request-tool',
    );

    expect(inspection.safety, TurnReplaySafety.unknown);
    expect(inspection.requiresConfirmation, isTrue);
  });
}
