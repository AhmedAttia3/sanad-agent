import 'package:sanad_agent/evolution/db/agent_state_database.dart';
import 'package:sanad_agent/evolution/db/session_db.dart';
import 'package:sanad_agent/evolution/models/session_state.dart';
import 'package:sqlite3/sqlite3.dart';
import 'package:test/test.dart';

void main() {
  late AgentStateDatabase state;
  late SessionDB sessions;

  setUp(() {
    state = AgentStateDatabase.inMemory();
    sessions = SessionDB.fromState(state);
    sessions.saveSession(
      SessionState(
        sessionId: 'session-1',
        model: 'model-1',
        title: 'Initial title',
        titleStatus: SessionTitleStatus.pending,
        createdAt: DateTime.utc(2026, 7, 16),
        updatedAt: DateTime.utc(2026, 7, 16),
      ),
    );
  });

  tearDown(() => state.dispose());

  test('generated title replaces only the captured placeholder', () {
    expect(
      sessions.updateSessionTitleIfCurrent(
        'session-1',
        expectedTitle: 'Initial title',
        title: 'Generated title',
      ),
      isTrue,
    );
    final session = sessions.getSession('session-1');
    expect(session?.title, 'Generated title');
    expect(session?.titleStatus, SessionTitleStatus.finalized);
  });

  test('manual rename wins over a delayed generated title', () {
    sessions.updateSessionTitle('session-1', 'Manual title');

    expect(
      sessions.updateSessionTitleIfCurrent(
        'session-1',
        expectedTitle: 'Initial title',
        title: 'Generated title',
      ),
      isFalse,
    );
    expect(sessions.getSession('session-1')?.title, 'Manual title');
  });

  test('a final title rejects later automatic replacement', () {
    sessions.updateSessionTitle('session-1', 'Manual title');

    expect(
      sessions.updateSessionTitleIfCurrent(
        'session-1',
        expectedTitle: 'Manual title',
        title: 'Late automatic title',
      ),
      isFalse,
    );
  });

  test('deleted session rejects a delayed generated title', () {
    sessions.deleteSession('session-1');

    expect(
      sessions.updateSessionTitleIfCurrent(
        'session-1',
        expectedTitle: 'Initial title',
        title: 'Generated title',
      ),
      isFalse,
    );
    expect(sessions.getSession('session-1'), isNull);
  });

  test('pending title query returns only recoverable sessions', () {
    sessions.saveSession(
      SessionState(
        sessionId: 'final-session',
        model: 'model-1',
        title: 'Final title',
        createdAt: DateTime.utc(2026, 7, 16),
        updatedAt: DateTime.utc(2026, 7, 16),
      ),
    );

    expect(
      sessions.getPendingTitleSessions().map((session) => session.sessionId),
      ['session-1'],
    );
  });

  test('legacy session titles migrate as final', () {
    final raw = sqlite3.openInMemory();
    try {
      raw.execute('''
        CREATE TABLE sessions (
          session_id TEXT PRIMARY KEY,
          model TEXT NOT NULL,
          title TEXT,
          created_at TEXT NOT NULL,
          updated_at TEXT NOT NULL
        )
      ''');
      raw.execute(
        'INSERT INTO sessions (session_id, model, title, created_at, updated_at) VALUES (?, ?, ?, ?, ?)',
        [
          'legacy',
          'model-1',
          'Existing title',
          '2026-07-01T00:00:00Z',
          '2026-07-01T00:00:00Z',
        ],
      );
      final migratedState = AgentStateDatabase.fromConnection(raw);
      final migratedSessions = SessionDB.fromState(migratedState);

      expect(
        migratedSessions.getSession('legacy')?.titleStatus,
        SessionTitleStatus.finalized,
      );
    } finally {
      raw.dispose();
    }
  });
}
