import 'package:equatable/equatable.dart';

enum SessionExecutionState {
  idle,
  queued,
  running,
  waiting,
  blocked,
  resuming,
  stopping
  ;

  static SessionExecutionState fromWireValue(Object? value) {
    final wireValue = value?.toString();
    return SessionExecutionState.values.where((state) => state.name == wireValue).firstOrNull ??
        (throw FormatException('Unknown session execution state: $wireValue'));
  }
}

class SessionExecutionSnapshot extends Equatable {
  final String sessionId;
  final SessionExecutionState state;
  final String? workItemId;
  final String? requestId;
  final int revision;
  final DateTime? updatedAt;

  const SessionExecutionSnapshot({
    required this.sessionId,
    required this.state,
    required this.workItemId,
    required this.requestId,
    required this.revision,
    required this.updatedAt,
  });

  factory SessionExecutionSnapshot.virtualIdle(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      throw const FormatException(
        'A virtual execution snapshot requires a session id.',
      );
    }
    return SessionExecutionSnapshot(
      sessionId: normalizedSessionId,
      state: SessionExecutionState.idle,
      workItemId: null,
      requestId: null,
      revision: 0,
      updatedAt: null,
    );
  }

  factory SessionExecutionSnapshot.fromJson(
    Map<String, dynamic> json, {
    String? expectedSessionId,
  }) {
    final sessionId = json['session_id']?.toString().trim() ?? '';
    if (sessionId.isEmpty) {
      throw const FormatException(
        'session_id is required for an execution snapshot.',
      );
    }
    if (expectedSessionId != null && sessionId != expectedSessionId) {
      throw FormatException(
        'Execution snapshot session_id $sessionId does not match $expectedSessionId.',
      );
    }

    final revisionValue = json['revision'];
    if (revisionValue is! num || revisionValue.toInt() != revisionValue || revisionValue.isNegative) {
      throw FormatException(
        'Execution snapshot revision must be a non-negative integer: $revisionValue',
      );
    }

    final updatedAtValue = json['updated_at'];
    final updatedAt = updatedAtValue == null ? null : DateTime.tryParse(updatedAtValue.toString());
    if (updatedAtValue != null && updatedAt == null) {
      throw FormatException(
        'Invalid execution snapshot updated_at: $updatedAtValue',
      );
    }

    return SessionExecutionSnapshot(
      sessionId: sessionId,
      state: SessionExecutionState.fromWireValue(json['state']),
      workItemId: _nullableString(json['work_item_id']),
      requestId: _nullableString(json['request_id']),
      revision: revisionValue.toInt(),
      updatedAt: updatedAt,
    );
  }

  static SessionExecutionSnapshot fromNullablePayload(
    Map<String, dynamic>? payload, {
    required String sessionId,
  }) {
    return payload == null
        ? SessionExecutionSnapshot.virtualIdle(sessionId)
        : SessionExecutionSnapshot.fromJson(
            payload,
            expectedSessionId: sessionId,
          );
  }

  bool get isExecuting => state == SessionExecutionState.running || state == SessionExecutionState.resuming;
  bool get hasActiveWork => state != SessionExecutionState.idle;
  bool get canStop => switch (state) {
    SessionExecutionState.queued ||
    SessionExecutionState.running ||
    SessionExecutionState.waiting ||
    SessionExecutionState.blocked ||
    SessionExecutionState.resuming => true,
    SessionExecutionState.idle || SessionExecutionState.stopping => false,
  };
  bool get needsUserAction => state == SessionExecutionState.blocked;
  bool get isWaiting => state == SessionExecutionState.waiting;
  bool get isStopping => state == SessionExecutionState.stopping;

  static String? _nullableString(Object? value) {
    final normalized = value?.toString().trim();
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  @override
  List<Object?> get props => [
    sessionId,
    state,
    workItemId,
    requestId,
    revision,
    updatedAt,
  ];
}
