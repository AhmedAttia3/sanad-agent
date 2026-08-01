import 'dart:async';

import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/evolution/db/persisted_runtime_state_repository.dart';
import 'package:sanad_agent/evolution/models/session_execution_snapshot.dart';
import 'package:sanad_agent/evolution/session_manager.dart';
import 'package:sanad_agent/interfaces/models/agent_turn_request.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart';
import 'package:sanad_agent/interfaces/runtime/session_run_orchestrator.dart';
import 'package:sanad_agent/interfaces/runtime/turn_replay_service.dart';

import '../sanad_protocol_bridge.dart';

class SessionTurnReplayCommandHandler {
  final SessionRunOrchestrator _orchestrator;
  final SessionManager _sessionManager;
  final PersistedRuntimeStateRepository? _persistedState;
  final SanadProtocolBridge _bridge;
  final Set<String> _sessionsInFlight = <String>{};

  SessionTurnReplayCommandHandler({
    required SessionRunOrchestrator orchestrator,
    required SessionManager sessionManager,
    PersistedRuntimeStateRepository? persistedState,
    required SanadProtocolBridge bridge,
  }) : _orchestrator = orchestrator,
       _sessionManager = sessionManager,
       _persistedState = persistedState,
       _bridge = bridge;

  Future<void> handle(
    CanonicalEvent event,
    Future<void> Function(Map<String, dynamic> envelope) emitEnvelope,
  ) async {
    final sessionId =
        event.sessionId ?? event.payload['session_id']?.toString() ?? '';
    final targetRequestId =
        event.payload['target_request_id']?.toString().trim() ?? '';
    final commandRequestId =
        event.payload['request_id']?.toString().trim() ?? '';
    final action = event.payload['action']?.toString() ?? 'retry';
    final confirmed = event.payload['confirmed_replay_unsafe'] == true;

    if (sessionId.isEmpty ||
        targetRequestId.isEmpty ||
        commandRequestId.isEmpty) {
      await _emitResult(
        emitEnvelope,
        sessionId: sessionId,
        requestId: commandRequestId,
        targetRequestId: targetRequestId,
        action: action,
        outcome: 'invalid_request',
        safety: TurnReplaySafety.unknown,
      );
      return;
    }
    if (action != 'retry' && action != 'edit') {
      await _emitResult(
        emitEnvelope,
        sessionId: sessionId,
        requestId: commandRequestId,
        targetRequestId: targetRequestId,
        action: action,
        outcome: 'invalid_request',
        safety: TurnReplaySafety.unknown,
      );
      return;
    }
    if (!_sessionsInFlight.add(sessionId)) {
      await _emitResult(
        emitEnvelope,
        sessionId: sessionId,
        requestId: commandRequestId,
        targetRequestId: targetRequestId,
        action: action,
        outcome: 'already_in_progress',
        safety: TurnReplaySafety.unknown,
      );
      return;
    }

    try {
      final replay = TurnReplayService(
        sessionManager: _sessionManager,
        persistedState: _persistedState,
      );
      final inspection = replay.inspect(
        sessionId: sessionId,
        targetRequestId: targetRequestId,
      );
      if (!inspection.canReplay) {
        await _emitResult(
          emitEnvelope,
          sessionId: sessionId,
          requestId: commandRequestId,
          targetRequestId: targetRequestId,
          action: action,
          outcome: _failureName(inspection.failure!),
          safety: inspection.safety,
        );
        return;
      }
      if (inspection.requiresConfirmation && !confirmed) {
        await _emitResult(
          emitEnvelope,
          sessionId: sessionId,
          requestId: commandRequestId,
          targetRequestId: targetRequestId,
          action: action,
          outcome: 'confirmation_required',
          safety: inspection.safety,
          requiresConfirmation: true,
        );
        return;
      }

      final editedMessage = event.payload['message']?.toString().trim();
      final replayMessage = action == 'edit'
          ? (editedMessage ?? '')
          : inspection.originalMessage;
      if (replayMessage.isEmpty) {
        await _emitResult(
          emitEnvelope,
          sessionId: sessionId,
          requestId: commandRequestId,
          targetRequestId: targetRequestId,
          action: action,
          outcome: 'empty_message',
          safety: inspection.safety,
        );
        return;
      }

      await _orchestrator.requestStop(sessionId);
      final execution = _persistedState?.executionSnapshots.getSnapshot(
        sessionId,
      );
      if (execution != null && execution.state != SessionExecutionState.idle) {
        await _emitResult(
          emitEnvelope,
          sessionId: sessionId,
          requestId: commandRequestId,
          targetRequestId: targetRequestId,
          action: action,
          outcome: 'session_not_idle',
          safety: inspection.safety,
        );
        return;
      }
      if (!replay.truncateAtTarget(inspection)) {
        await _emitResult(
          emitEnvelope,
          sessionId: sessionId,
          requestId: commandRequestId,
          targetRequestId: targetRequestId,
          action: action,
          outcome: 'stale_turn_boundary',
          safety: inspection.safety,
        );
        return;
      }

      final session = _sessionManager.getSession(sessionId);
      final providerInstanceId = event.payload['provider_instance_id']
          ?.toString()
          .trim();
      final modelId = (event.payload['model_id'] ?? event.payload['model'])
          ?.toString()
          .trim();
      final thinkingMode = event.payload['thinking_mode']?.toString().trim();
      final request = AgentTurnRequest(
        sessionId: sessionId,
        message: replayMessage,
        workspaceId: session?.workspaceId,
        providerInstanceId:
            providerInstanceId == null || providerInstanceId.isEmpty
            ? null
            : providerInstanceId,
        model: modelId == null || modelId.isEmpty ? null : modelId,
        thinkingMode: thinkingMode == null || thinkingMode.isEmpty
            ? null
            : thinkingMode,
        requestId: commandRequestId,
        metadata: {
          'turn_replay_action': action,
          'replayed_request_id': targetRequestId,
        },
      );
      final gatewayEvent = GatewayEvent(
        sessionId: sessionId,
        platformId: 'sanad_client',
        message: Message(role: MessageRole.user, content: replayMessage),
        metadata: {'command': 'think', 'payload': request.toMetadata()},
        turnRequest: request,
      );

      await _emitResult(
        emitEnvelope,
        sessionId: sessionId,
        requestId: commandRequestId,
        targetRequestId: targetRequestId,
        action: action,
        outcome: 'accepted',
        safety: inspection.safety,
      );
      unawaited(_orchestrator.handleEvent(gatewayEvent));
    } catch (_) {
      await _emitResult(
        emitEnvelope,
        sessionId: sessionId,
        requestId: commandRequestId,
        targetRequestId: targetRequestId,
        action: action,
        outcome: 'failed',
        safety: TurnReplaySafety.unknown,
      );
    } finally {
      _sessionsInFlight.remove(sessionId);
    }
  }

  Future<void> _emitResult(
    Future<void> Function(Map<String, dynamic> envelope) emitEnvelope, {
    required String sessionId,
    required String requestId,
    required String targetRequestId,
    required String action,
    required String outcome,
    required TurnReplaySafety safety,
    bool requiresConfirmation = false,
  }) {
    return emitEnvelope(
      _bridge.buildAgentEventEnvelope(
        CanonicalEvent(
          type: CanonicalEventTypes.sessionTurnReplayResult,
          sessionId: sessionId,
          payload: {
            'session_id': sessionId,
            'request_id': requestId,
            'target_request_id': targetRequestId,
            'action': action,
            'outcome': outcome,
            'replay_safety': safety.name,
            'requires_confirmation': requiresConfirmation,
          },
        ),
      ),
    );
  }

  static String _failureName(TurnReplayInspectionFailure failure) =>
      switch (failure) {
        TurnReplayInspectionFailure.sessionNotFound => 'session_not_found',
        TurnReplayInspectionFailure.targetNotFound => 'turn_boundary_not_found',
        TurnReplayInspectionFailure.targetIsNotLatestTurn => 'not_latest_turn',
        TurnReplayInspectionFailure.emptyMessage => 'empty_message',
      };
}
