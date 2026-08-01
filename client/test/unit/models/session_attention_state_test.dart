import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/device_suspended_request.dart';
import 'package:sanad_client/features/conversations/domain/models/runtime_notice.dart';
import 'package:sanad_client/features/conversations/domain/models/session_attention_state.dart';
import 'package:sanad_client/features/conversations/domain/models/session_execution_snapshot.dart';

void main() {
  test('applies the canonical attention priority', () {
    final blocked = _attention(
      SessionExecutionState.running,
      notice: const RuntimeNotice(
        sessionId: 'session-1',
        status: 'blocked',
        reason: 'network',
        title: 'Blocked',
      ),
    );
    expect(blocked.visualState, SessionAttentionVisualState.blockedOrFatal);

    final permission = SessionAttentionState(
      sessionId: 'session-1',
      executionSnapshot: blocked.executionSnapshot,
      runtimeNotice: blocked.runtimeNotice,
      pendingSuspendedRequest: DeviceSuspendedRequest.fromJson({
        'session_id': 'session-1',
        'request_id': 'permission-1',
        'tool_name': 'shell_execute',
      }),
    );
    expect(
      permission.visualState,
      SessionAttentionVisualState.userQuestionOrPermission,
    );
  });

  for (final entry in const {
    SessionExecutionState.idle: SessionAttentionVisualState.normal,
    SessionExecutionState.queued: SessionAttentionVisualState.queued,
    SessionExecutionState.running: SessionAttentionVisualState.runningOrResuming,
    SessionExecutionState.waiting: SessionAttentionVisualState.waiting,
    SessionExecutionState.blocked: SessionAttentionVisualState.blockedOrFatal,
    SessionExecutionState.resuming: SessionAttentionVisualState.runningOrResuming,
    SessionExecutionState.stopping: SessionAttentionVisualState.stopping,
  }.entries) {
    test('maps ${entry.key.name} to ${entry.value.name}', () {
      expect(_attention(entry.key).visualState, entry.value);
    });
  }
}

SessionAttentionState _attention(
  SessionExecutionState state, {
  RuntimeNotice? notice,
}) => SessionAttentionState(
  sessionId: 'session-1',
  executionSnapshot: SessionExecutionSnapshot(
    sessionId: 'session-1',
    state: state,
    workItemId: state == SessionExecutionState.idle ? null : 'work-1',
    requestId: state == SessionExecutionState.idle ? null : 'request-1',
    revision: 1,
    updatedAt: DateTime.utc(2026, 7, 15),
  ),
  runtimeNotice: notice,
  pendingSuspendedRequest: null,
);
