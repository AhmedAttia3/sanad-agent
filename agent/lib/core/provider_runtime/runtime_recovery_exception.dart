import 'runtime_failure_reason.dart';

/// Signals that execution intentionally paused in a recoverable runtime state.
///
/// The orchestrator should not emit a generic assistant error for this case;
/// instead it stores the pending work item until the user retries, stops, or
/// switches provider.
class RuntimeRecoveryRequired implements Exception {
  final String sessionId;
  final RuntimeFailureReason reason;

  const RuntimeRecoveryRequired(this.sessionId, this.reason);

  @override
  String toString() =>
      'RuntimeRecoveryRequired(session=$sessionId, reason=${reason.name})';
}

/// Signals that a recovery wait was intentionally cancelled by `stop` or
/// `continue_with_provider`.
class RuntimeRecoveryCancelled implements Exception {
  final String sessionId;

  const RuntimeRecoveryCancelled(this.sessionId);

  @override
  String toString() => 'RuntimeRecoveryCancelled(session=$sessionId)';
}
