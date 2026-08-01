import 'package:sanad_agent/core/di.dart';
import 'package:sanad_agent/evolution/db/agent_state_database.dart';
import 'package:sanad_agent/evolution/db/persisted_runtime_state_repository.dart';
import 'package:sanad_agent/interfaces/models/agent_turn_request.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/sanad_protocol_bridge.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/translators/canonical_to_agent.dart';
import 'package:sanad_agent/interfaces/runtime/session_run_orchestrator.dart';
import 'package:test/test.dart';

void main() {
  test(
    'missing delivery intent defaults to auto without conflating request/run ids',
    () {
      final event = CanonicalToAgent.translate({
        'command': 'think',
        'payload': {
          'session_id': 'session-1',
          'request_id': 'request-1',
          'message': 'hello',
        },
      }, 'test');

      expect(event, isNotNull);
      expect(event!.runId, isNull);
      expect(event.turnRequest!.requestId, 'request-1');
      expect(event.turnRequest!.deliveryIntent, MessageDeliveryIntent.auto);
    },
  );

  test(
    'queue delivery intent is typed and preserves an independent run id',
    () {
      final event = CanonicalToAgent.translate({
        'command': 'think',
        'payload': {
          'session_id': 'session-2',
          'request_id': 'request-2',
          'run_id': 'run-2',
          'delivery_intent': 'queue',
          'message': 'later',
        },
      }, 'test');

      expect(event!.runId, 'run-2');
      expect(event.turnRequest!.requestId, 'request-2');
      expect(event.turnRequest!.deliveryIntent, MessageDeliveryIntent.queue);
    },
  );

  test('stop translation preserves its private recovery owner token', () {
    final event = CanonicalToAgent.translate({
      'command': 'stop',
      'payload': {
        'session_id': 'session-stop-owner',
        'request_id': 'stop-owner-request',
        'recovery_owner_token': 'private-owner-token',
      },
    }, 'test');

    expect(
      (event!.metadata['payload'] as Map)['recovery_owner_token'],
      'private-owner-token',
    );
  });

  test(
    'queued delete protocol command cancels the durable target id',
    () async {
      await getIt.reset();
      final state = AgentStateDatabase.inMemory();
      addTearDown(() async {
        await getIt.reset();
        state.dispose();
      });
      state.db.execute(
        'INSERT INTO sessions (session_id, model, created_at, updated_at) '
        'VALUES (?, ?, ?, ?)',
        ['session-delete', 'test', '2026-07-15', '2026-07-15'],
      );
      final runtime = PersistedRuntimeStateRepository(state.db);
      runtime.executionState.enqueueWorkItem(
        workItemId: 'work-delete',
        sessionId: 'session-delete',
        requestId: 'target-delete',
      );
      getIt.registerSingleton<PersistedRuntimeStateRepository>(runtime);
      getIt.registerSingleton<SessionRunOrchestrator>(SessionRunOrchestrator());

      await SanadProtocolBridge().handleProtocolEvent(
        CanonicalEvent(
          type: CanonicalEventTypes.sessionQueuedMessageDelete,
          sessionId: 'session-delete',
          payload: const {
            'request_id': 'target-delete',
            'command_request_id': 'command-delete',
          },
        ),
        (_) async {},
      );

      expect(
        runtime.workItems.findWorkItem('work-delete')!.state.name,
        'cancelled',
      );
    },
  );

  test('user stop ack requires the private recovery owner token', () async {
    await getIt.reset();
    final state = AgentStateDatabase.inMemory();
    addTearDown(() async {
      await getIt.reset();
      state.dispose();
    });
    state.db.execute(
      'INSERT INTO sessions (session_id, model, created_at, updated_at) '
      'VALUES (?, ?, ?, ?)',
      ['session-stop-ack', 'test', '2026-07-15', '2026-07-15'],
    );
    final runtime = PersistedRuntimeStateRepository(state.db);
    runtime.pendingInputs.saveStopOutcome(
      sessionId: 'session-stop-ack',
      stopRequestId: 'stop-ack-request',
      items: const [],
      recoveryOwnerToken: 'private-owner-token',
    );
    getIt.registerSingleton<PersistedRuntimeStateRepository>(runtime);
    getIt.registerSingleton<SessionRunOrchestrator>(SessionRunOrchestrator());
    final bridge = SanadProtocolBridge();

    await bridge.handleProtocolEvent(
      CanonicalEvent(
        type: CanonicalEventTypes.sessionStopRecoveryAck,
        sessionId: 'session-stop-ack',
        payload: const {
          'stop_request_id': 'stop-ack-request',
          'recovery_owner_token': 'wrong-owner-token',
        },
      ),
      (_) async {},
    );
    expect(
      runtime.pendingInputs.findStopOutcome('stop-ack-request')!.isAcknowledged,
      isFalse,
    );

    await bridge.handleProtocolEvent(
      CanonicalEvent(
        type: CanonicalEventTypes.sessionStopRecoveryAck,
        sessionId: 'session-stop-ack',
        payload: const {
          'stop_request_id': 'stop-ack-request',
          'recovery_owner_token': 'private-owner-token',
        },
      ),
      (_) async {},
    );
    expect(
      runtime.pendingInputs.findStopOutcome('stop-ack-request')!.isAcknowledged,
      isTrue,
    );
  });
}
