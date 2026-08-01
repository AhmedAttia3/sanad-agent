import 'package:equatable/equatable.dart';
import 'package:sanad_client/features/conversations/domain/models/session_route_snapshot.dart';

enum SessionRouteApplyDisposition {
  applied,
  idempotent,
  rejectedStaleRevision,
  rejectedConflictingRevision,
}

class SessionRouteApplyResult extends Equatable {
  final SessionRouteApplyDisposition disposition;
  final SessionRouteSnapshot? previous;
  final SessionRouteSnapshot current;
  final String diagnostic;

  const SessionRouteApplyResult({
    required this.disposition,
    required this.previous,
    required this.current,
    required this.diagnostic,
  });

  bool get accepted =>
      disposition == SessionRouteApplyDisposition.applied || disposition == SessionRouteApplyDisposition.idempotent;
  bool get changed => disposition == SessionRouteApplyDisposition.applied;

  @override
  List<Object?> get props => [disposition, previous, current, diagnostic];
}

class SessionRouteRegistry {
  final Map<String, SessionRouteSnapshot> _routesBySessionId = {};

  Map<String, SessionRouteSnapshot> get routesBySessionId => Map.unmodifiable(_routesBySessionId);

  SessionRouteSnapshot? routeFor(String sessionId) => _routesBySessionId[sessionId];

  SessionRouteApplyResult apply(SessionRouteSnapshot incoming) {
    final previous = routeFor(incoming.sessionId);
    if (previous != null && incoming.routeRevision < previous.routeRevision) {
      return SessionRouteApplyResult(
        disposition: SessionRouteApplyDisposition.rejectedStaleRevision,
        previous: previous,
        current: previous,
        diagnostic:
            'Rejected stale route revision ${incoming.routeRevision} for ${incoming.sessionId}; current revision is ${previous.routeRevision}.',
      );
    }
    if (previous != null && incoming.routeRevision == previous.routeRevision) {
      if (incoming == previous) {
        return SessionRouteApplyResult(
          disposition: SessionRouteApplyDisposition.idempotent,
          previous: previous,
          current: previous,
          diagnostic: 'Route revision ${incoming.routeRevision} for ${incoming.sessionId} is an identical replay.',
        );
      }
      if (incoming.hasSameAuthoritativeRoute(previous)) {
        if (incoming.transitionMetadataRichness > previous.transitionMetadataRichness) {
          _routesBySessionId[incoming.sessionId] = incoming;
          return SessionRouteApplyResult(
            disposition: SessionRouteApplyDisposition.applied,
            previous: previous,
            current: incoming,
            diagnostic:
                'Enriched route revision ${incoming.routeRevision} for ${incoming.sessionId} with transition metadata.',
          );
        }
        return SessionRouteApplyResult(
          disposition: SessionRouteApplyDisposition.idempotent,
          previous: previous,
          current: previous,
          diagnostic:
              'Route revision ${incoming.routeRevision} for ${incoming.sessionId} repeats the same authoritative route.',
        );
      }
      return SessionRouteApplyResult(
        disposition: SessionRouteApplyDisposition.rejectedConflictingRevision,
        previous: previous,
        current: previous,
        diagnostic:
            'Rejected conflicting route payload at revision ${incoming.routeRevision} for ${incoming.sessionId}.',
      );
    }
    _routesBySessionId[incoming.sessionId] = incoming;
    return SessionRouteApplyResult(
      disposition: SessionRouteApplyDisposition.applied,
      previous: previous,
      current: incoming,
      diagnostic: 'Applied route revision ${incoming.routeRevision} for ${incoming.sessionId}.',
    );
  }

  SessionRouteApplyResult applyPayload(
    Map<String, dynamic> payload, {
    String? expectedSessionId,
  }) => apply(
    SessionRouteSnapshot.fromJson(
      payload,
      expectedSessionId: expectedSessionId,
    ),
  );
}
