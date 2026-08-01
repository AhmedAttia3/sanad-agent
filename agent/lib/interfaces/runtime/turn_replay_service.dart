import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/evolution/db/persisted_runtime_state_repository.dart';
import 'package:sanad_agent/evolution/session_manager.dart';

enum TurnReplaySafety { safe, unsafe, unknown }

enum TurnReplayInspectionFailure {
  sessionNotFound,
  targetNotFound,
  targetIsNotLatestTurn,
  emptyMessage,
}

class TurnReplayInspection {
  final String sessionId;
  final String targetRequestId;
  final String originalMessage;
  final int targetMessageIndex;
  final TurnReplaySafety safety;
  final TurnReplayInspectionFailure? failure;

  const TurnReplayInspection({
    required this.sessionId,
    required this.targetRequestId,
    required this.originalMessage,
    required this.targetMessageIndex,
    required this.safety,
    this.failure,
  });

  bool get canReplay => failure == null;
  bool get requiresConfirmation =>
      safety == TurnReplaySafety.unsafe || safety == TurnReplaySafety.unknown;
}

/// Resolves a historical turn boundary and its daemon-owned tool replay safety.
///
/// Task 49 deliberately permits replay only for the latest user turn. Editing
/// an older turn would also discard newer user-owned turns, which requires a
/// separate conversation-branching contract.
class TurnReplayService {
  final SessionManager _sessionManager;
  final PersistedRuntimeStateRepository? _persistedState;

  const TurnReplayService({
    required SessionManager sessionManager,
    PersistedRuntimeStateRepository? persistedState,
  }) : _sessionManager = sessionManager,
       _persistedState = persistedState;

  TurnReplayInspection inspect({
    required String sessionId,
    required String targetRequestId,
  }) {
    final session = _sessionManager.getSession(sessionId);
    if (session == null) {
      return _failure(
        sessionId,
        targetRequestId,
        TurnReplayInspectionFailure.sessionNotFound,
      );
    }

    final messages = session.messages;
    final targetIndex = messages.lastIndexWhere(
      (message) =>
          message.role == MessageRole.user &&
          message.metadata?['request_id']?.toString() == targetRequestId,
    );
    if (targetIndex < 0) {
      return _failure(
        sessionId,
        targetRequestId,
        TurnReplayInspectionFailure.targetNotFound,
      );
    }

    final latestUserIndex = messages.lastIndexWhere(
      (message) => message.role == MessageRole.user,
    );
    if (targetIndex != latestUserIndex) {
      return _failure(
        sessionId,
        targetRequestId,
        TurnReplayInspectionFailure.targetIsNotLatestTurn,
      );
    }

    final originalMessage = messages[targetIndex].content?.trim() ?? '';
    if (originalMessage.isEmpty) {
      return _failure(
        sessionId,
        targetRequestId,
        TurnReplayInspectionFailure.emptyMessage,
      );
    }

    final toolCallIds = <String>{};
    for (final message in messages.skip(targetIndex + 1)) {
      for (final toolCall in message.toolCalls ?? const []) {
        toolCallIds.add(toolCall.id);
      }
    }

    var safety = TurnReplaySafety.safe;
    if (toolCallIds.isNotEmpty) {
      final workItem = _persistedState?.workItems.findByRequestId(
        sessionId,
        targetRequestId,
      );
      final replaySafety = Map<String, dynamic>.from(
        workItem?.continuationMetadata['tool_replay_safety'] as Map? ??
            const {},
      );
      if (toolCallIds.any((id) => replaySafety[id] == false)) {
        safety = TurnReplaySafety.unsafe;
      } else if (toolCallIds.any((id) => replaySafety[id] != true)) {
        safety = TurnReplaySafety.unknown;
      }
    }

    return TurnReplayInspection(
      sessionId: sessionId,
      targetRequestId: targetRequestId,
      originalMessage: originalMessage,
      targetMessageIndex: targetIndex,
      safety: safety,
    );
  }

  /// Removes the target user turn and every assistant/tool artifact owned by
  /// it. The caller must establish and re-check an authoritative idle boundary
  /// before invoking this mutation.
  bool truncateAtTarget(TurnReplayInspection inspection) {
    if (!inspection.canReplay) return false;
    final session = _sessionManager.getSession(inspection.sessionId);
    if (session == null ||
        inspection.targetMessageIndex < 0 ||
        inspection.targetMessageIndex >= session.messages.length) {
      return false;
    }
    final target = session.messages[inspection.targetMessageIndex];
    if (target.role != MessageRole.user ||
        target.metadata?['request_id']?.toString() !=
            inspection.targetRequestId) {
      return false;
    }
    final latestUserIndex = session.messages.lastIndexWhere(
      (message) => message.role == MessageRole.user,
    );
    if (latestUserIndex != inspection.targetMessageIndex) return false;

    _sessionManager.saveSessionHistory(
      inspection.sessionId,
      session.messages
          .take(inspection.targetMessageIndex)
          .toList(growable: true),
    );
    return true;
  }

  TurnReplayInspection _failure(
    String sessionId,
    String targetRequestId,
    TurnReplayInspectionFailure failure,
  ) {
    return TurnReplayInspection(
      sessionId: sessionId,
      targetRequestId: targetRequestId,
      originalMessage: '',
      targetMessageIndex: -1,
      safety: TurnReplaySafety.unknown,
      failure: failure,
    );
  }
}
