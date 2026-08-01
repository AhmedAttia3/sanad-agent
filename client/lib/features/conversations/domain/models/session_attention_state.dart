import 'package:equatable/equatable.dart';
import 'package:sanad_client/features/conversations/domain/models/device_suspended_request.dart';
import 'package:sanad_client/features/conversations/domain/models/runtime_notice.dart';
import 'package:sanad_client/features/conversations/domain/models/session_execution_snapshot.dart';

enum SessionAttentionVisualState {
  userQuestionOrPermission,
  blockedOrFatal,
  waiting,
  stopping,
  runningOrResuming,
  queued,
  normal,
}

class SessionAttentionState extends Equatable {
  final String sessionId;
  final SessionExecutionSnapshot executionSnapshot;
  final RuntimeNotice? runtimeNotice;
  final DeviceSuspendedRequest? pendingSuspendedRequest;

  const SessionAttentionState({
    required this.sessionId,
    required this.executionSnapshot,
    required this.runtimeNotice,
    required this.pendingSuspendedRequest,
  });

  String get attentionRevision => [
    'execution:${executionSnapshot.revision}',
    'notice:${runtimeNotice?.requestId ?? '-'}:${runtimeNotice?.status ?? '-'}',
    'permission:${pendingSuspendedRequest?.requestId ?? '-'}',
  ].join('|');

  SessionAttentionVisualState get visualState {
    if (pendingSuspendedRequest != null) {
      return SessionAttentionVisualState.userQuestionOrPermission;
    }
    if (executionSnapshot.state == SessionExecutionState.blocked ||
        runtimeNotice?.isBlocked == true ||
        runtimeNotice?.isFatal == true) {
      return SessionAttentionVisualState.blockedOrFatal;
    }
    if (executionSnapshot.state == SessionExecutionState.waiting || runtimeNotice?.isWaiting == true) {
      return SessionAttentionVisualState.waiting;
    }
    return switch (executionSnapshot.state) {
      SessionExecutionState.stopping => SessionAttentionVisualState.stopping,
      SessionExecutionState.running || SessionExecutionState.resuming => SessionAttentionVisualState.runningOrResuming,
      SessionExecutionState.queued => SessionAttentionVisualState.queued,
      SessionExecutionState.idle ||
      SessionExecutionState.waiting ||
      SessionExecutionState.blocked => SessionAttentionVisualState.normal,
    };
  }

  @override
  List<Object?> get props => [
    sessionId,
    executionSnapshot,
    runtimeNotice,
    pendingSuspendedRequest,
  ];
}
