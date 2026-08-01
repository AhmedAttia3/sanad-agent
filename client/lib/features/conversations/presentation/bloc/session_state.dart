import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:equatable/equatable.dart';
import 'package:sanad_client/features/conversations/domain/models/session_attention_state.dart';
import 'package:sanad_client/features/conversations/domain/models/session_route_snapshot.dart';

class SessionState extends Equatable {
  final Session? selectedSession;
  final Map<String, List<Session>> agentSessions;
  final Map<String, bool> loadingSessions;
  final Map<String, Set<String>> processingSessionIds;
  final Map<String, Set<String>> suspendedSessionIds;
  final Map<String, Map<String, SessionAttentionState>> attentionStates;
  final Map<String, Map<String, SessionRouteSnapshot>> routeSnapshots;
  final String? error;

  const SessionState({
    this.selectedSession,
    this.agentSessions = const {},
    this.loadingSessions = const {},
    this.processingSessionIds = const {},
    this.suspendedSessionIds = const {},
    this.attentionStates = const {},
    this.routeSnapshots = const {},
    this.error,
  });

  SessionState copyWith({
    Session? selectedSession,
    bool clearSelectedSession = false,
    Map<String, List<Session>>? agentSessions,
    Map<String, bool>? loadingSessions,
    Map<String, Set<String>>? processingSessionIds,
    Map<String, Set<String>>? suspendedSessionIds,
    Map<String, Map<String, SessionAttentionState>>? attentionStates,
    Map<String, Map<String, SessionRouteSnapshot>>? routeSnapshots,
    String? error,
    bool clearError = false,
  }) {
    return SessionState(
      selectedSession: clearSelectedSession ? null : selectedSession ?? this.selectedSession,
      agentSessions: agentSessions ?? this.agentSessions,
      loadingSessions: loadingSessions ?? this.loadingSessions,
      processingSessionIds: processingSessionIds ?? this.processingSessionIds,
      suspendedSessionIds: suspendedSessionIds ?? this.suspendedSessionIds,
      attentionStates: attentionStates ?? this.attentionStates,
      routeSnapshots: routeSnapshots ?? this.routeSnapshots,
      error: clearError ? null : error ?? this.error,
    );
  }

  bool isSessionProcessing(String deviceId, String sessionId) =>
      processingSessionIds[deviceId]?.contains(sessionId) ?? false;
  bool hasPendingSuspension(String deviceId, String sessionId) =>
      suspendedSessionIds[deviceId]?.contains(sessionId) ?? false;
  SessionAttentionState? attentionStateFor(String deviceId, String sessionId) => attentionStates[deviceId]?[sessionId];
  SessionRouteSnapshot? routeSnapshotFor(String deviceId, String sessionId) => routeSnapshots[deviceId]?[sessionId];

  @override
  List<Object?> get props => [
    selectedSession,
    agentSessions,
    loadingSessions,
    processingSessionIds,
    suspendedSessionIds,
    attentionStates,
    routeSnapshots,
    error,
  ];
}
