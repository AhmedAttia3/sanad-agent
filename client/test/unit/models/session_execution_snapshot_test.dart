import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/session_execution_snapshot.dart';

void main() {
  group('SessionExecutionSnapshot', () {
    for (final state in SessionExecutionState.values) {
      test('parses ${state.name} and derives its presentation flags', () {
        final snapshot = SessionExecutionSnapshot.fromJson({
          'session_id': 'session-1',
          'state': state.name,
          'work_item_id': state == SessionExecutionState.idle ? null : 'work-1',
          'request_id': state == SessionExecutionState.idle ? null : 'request-1',
          'revision': 4,
          'updated_at': '2026-07-15T10:30:00Z',
        });

        expect(snapshot.state, state);
        expect(
          snapshot.isExecuting,
          state == SessionExecutionState.running || state == SessionExecutionState.resuming,
        );
        expect(snapshot.hasActiveWork, state != SessionExecutionState.idle);
        expect(
          snapshot.canStop,
          const {
            SessionExecutionState.queued,
            SessionExecutionState.running,
            SessionExecutionState.waiting,
            SessionExecutionState.blocked,
            SessionExecutionState.resuming,
          }.contains(state),
        );
        expect(
          snapshot.needsUserAction,
          state == SessionExecutionState.blocked,
        );
        expect(snapshot.isWaiting, state == SessionExecutionState.waiting);
        expect(snapshot.isStopping, state == SessionExecutionState.stopping);
      });
    }

    test(
      'creates virtual idle revision zero when no durable payload exists',
      () {
        final snapshot = SessionExecutionSnapshot.fromNullablePayload(
          null,
          sessionId: 'session-old',
        );

        expect(snapshot.sessionId, 'session-old');
        expect(snapshot.state, SessionExecutionState.idle);
        expect(snapshot.revision, 0);
        expect(snapshot.workItemId, isNull);
        expect(snapshot.requestId, isNull);
        expect(snapshot.updatedAt, isNull);
      },
    );

    test('requires an explicit matching session id', () {
      expect(
        () => SessionExecutionSnapshot.fromJson({'state': 'idle', 'revision': 0}),
        throwsFormatException,
      );
      expect(
        () => SessionExecutionSnapshot.fromJson({
          'session_id': 'session-a',
          'state': 'idle',
          'revision': 0,
        }, expectedSessionId: 'session-b'),
        throwsFormatException,
      );
    });

    test('rejects unknown state, invalid revision, and invalid timestamp', () {
      expect(
        () => SessionExecutionSnapshot.fromJson({
          'session_id': 'session-1',
          'state': 'finishing',
          'revision': 1,
        }),
        throwsFormatException,
      );
      expect(
        () => SessionExecutionSnapshot.fromJson({
          'session_id': 'session-1',
          'state': 'idle',
          'revision': -1,
        }),
        throwsFormatException,
      );
      expect(
        () => SessionExecutionSnapshot.fromJson({
          'session_id': 'session-1',
          'state': 'idle',
          'revision': 1,
          'updated_at': 'not-a-date',
        }),
        throwsFormatException,
      );
    });
  });
}
