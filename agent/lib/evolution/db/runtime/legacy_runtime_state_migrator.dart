import 'dart:convert';

import 'package:sqlite3/sqlite3.dart';

import '../persisted_runtime_state_repository.dart';

/// Compatibility + cleanup helpers for the legacy
/// `session_suspended_runs` and `session_pending_runs` tables.
///
/// Since Gate C.1, `session_work_items` is the single source of truth for
/// queued and suspended work. The legacy tables may still exist in databases
/// created before the migration, so these methods are retained to read and
/// purge stale rows during startup cleanup. Production code paths MUST NOT
/// enqueue work through this class.
///
/// Shares the same `AgentStateDatabase` connection as the other runtime
/// repositories so cross-table operations stay atomic.
class LegacyRuntimeStateMigrator {
  final Database _db;

  LegacyRuntimeStateMigrator(Database db) : _db = db;

  // ── Suspended runs (legacy, Gate C.1 single source of truth) ────────────

  /// Inserts or replaces the suspended run for [sessionId]. Legacy
  /// compatibility API. Do not call from new code — use
  /// `session_work_items` via `enqueueWorkItem` and the transition API.
  @Deprecated(
    'session_suspended_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  void upsertSuspendedRun({
    required String sessionId,
    String? requestId,
    String? runId,
    String? message,
    Map<String, dynamic>? eventMetadata,
    String? workspaceId,
    String? providerInstanceId,
    String? modelId,
    String? thinkingMode,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    _db.execute(
      '''
      INSERT INTO session_suspended_runs (
        session_id, request_id, run_id, message, event_metadata,
        workspace_id, provider_instance_id, model_id, thinking_mode,
        created_at, updated_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ON CONFLICT(session_id) DO UPDATE SET
        request_id = excluded.request_id,
        run_id = excluded.run_id,
        message = excluded.message,
        event_metadata = excluded.event_metadata,
        workspace_id = excluded.workspace_id,
        provider_instance_id = excluded.provider_instance_id,
        model_id = excluded.model_id,
        thinking_mode = excluded.thinking_mode,
        updated_at = excluded.updated_at
      ''',
      [
        sessionId,
        requestId,
        runId,
        message,
        jsonEncode(eventMetadata ?? {}),
        workspaceId,
        providerInstanceId,
        modelId,
        thinkingMode,
        now,
        now,
      ],
    );
  }

  /// Returns the suspended run for [sessionId], or null.
  @Deprecated(
    'session_suspended_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  PersistedSuspendedRun? findSuspendedRun(String sessionId) {
    final row = _db.select(
      'SELECT * FROM session_suspended_runs WHERE session_id = ?',
      [sessionId],
    );
    if (row.isEmpty) return null;
    return PersistedSuspendedRun.fromRow(row.first);
  }

  /// Returns all persisted suspended runs (used at daemon bootstrap).
  @Deprecated(
    'session_suspended_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  List<PersistedSuspendedRun> findAllSuspendedRuns() {
    final rows = _db.select('SELECT * FROM session_suspended_runs');
    return rows.map(PersistedSuspendedRun.fromRow).toList();
  }

  @Deprecated(
    'session_suspended_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  void deleteSuspendedRun(String sessionId) {
    _db.execute('DELETE FROM session_suspended_runs WHERE session_id = ?', [
      sessionId,
    ]);
  }

  // ── Pending runs (queued messages) ──────────────────────────────────────

  /// Appends a pending run to the end of [sessionId]'s queue. Legacy
  /// compatibility API — do not call from new code.
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  void appendPendingRun({
    required String sessionId,
    String? requestId,
    String? message,
    Map<String, dynamic>? eventMetadata,
    String? workspaceId,
    String? providerInstanceId,
    String? modelId,
    String? thinkingMode,
    String? runId,
    String eventType = 'message',
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final seq = _nextSeq(sessionId);
    _db.execute(
      '''
      INSERT INTO session_pending_runs (
        session_id, request_id, message, event_metadata,
        workspace_id, provider_instance_id, model_id, thinking_mode,
        run_id, event_type, seq, created_at
      ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''',
      [
        sessionId,
        requestId,
        message,
        jsonEncode(eventMetadata ?? {}),
        workspaceId,
        providerInstanceId,
        modelId,
        thinkingMode,
        runId,
        eventType,
        seq,
        now,
      ],
    );
  }

  /// Returns the pending runs for [sessionId] in FIFO order (by `seq`).
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  List<PersistedPendingRun> findPendingRuns(String sessionId) {
    final rows = _db.select(
      'SELECT * FROM session_pending_runs '
      'WHERE session_id = ? ORDER BY seq ASC',
      [sessionId],
    );
    return rows.map(PersistedPendingRun.fromRow).toList();
  }

  /// Returns all pending runs grouped by session (used at daemon bootstrap).
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  Map<String, List<PersistedPendingRun>> findAllPendingRuns() {
    final rows = _db.select(
      'SELECT * FROM session_pending_runs ORDER BY seq ASC',
    );
    final result = <String, List<PersistedPendingRun>>{};
    for (final row in rows) {
      final run = PersistedPendingRun.fromRow(row);
      (result[run.sessionId] ??= []).add(run);
    }
    return result;
  }

  /// Removes and returns the first pending run for [sessionId] (FIFO), or null.
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  PersistedPendingRun? popFirstPendingRun(String sessionId) {
    final rows = _db.select(
      'SELECT * FROM session_pending_runs '
      'WHERE session_id = ? ORDER BY seq ASC LIMIT 1',
      [sessionId],
    );
    if (rows.isEmpty) return null;
    final run = PersistedPendingRun.fromRow(rows.first);
    _db.execute('DELETE FROM session_pending_runs WHERE id = ?', [run.id]);
    return run;
  }

  /// Removes all pending runs for [sessionId].
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  void deleteAllPendingRuns(String sessionId) {
    _db.execute('DELETE FROM session_pending_runs WHERE session_id = ?', [
      sessionId,
    ]);
  }

  /// Updates the provider/model route on all pending runs for [sessionId].
  @Deprecated(
    'session_pending_runs is legacy. Use session_work_items (Gate C) as the single source of truth.',
  )
  void rewritePendingRoute(
    String sessionId, {
    String? providerInstanceId,
    String? modelId,
  }) {
    if (providerInstanceId != null) {
      _db.execute(
        'UPDATE session_pending_runs SET provider_instance_id = ? '
        'WHERE session_id = ?',
        [providerInstanceId, sessionId],
      );
    }
    if (modelId != null) {
      _db.execute(
        'UPDATE session_pending_runs SET model_id = ? '
        'WHERE session_id = ?',
        [modelId, sessionId],
      );
    }
  }

  /// Best-effort raw SQL cleanup of the legacy
  /// `session_suspended_runs` table for [sessionId]. Returns nothing
  /// because the cleanup is best-effort; transient failures must not
  /// prevent the authoritative notice/work-item cleanup required by
  /// `Stop`.
  void purgeLegacySuspendedRunsForSession(String sessionId) {
    try {
      _db.execute('DELETE FROM session_suspended_runs WHERE session_id = ?', [
        sessionId,
      ]);
    } catch (_) {}
  }

  /// Best-effort raw SQL cleanup of the legacy
  /// `session_pending_runs` table for [sessionId].
  void purgeLegacyPendingRunsForSession(String sessionId) {
    try {
      _db.execute('DELETE FROM session_pending_runs WHERE session_id = ?', [
        sessionId,
      ]);
    } catch (_) {}
  }

  int _nextSeq(String sessionId) {
    final rows = _db.select(
      'SELECT MAX(seq) AS max_seq FROM session_pending_runs '
      'WHERE session_id = ?',
      [sessionId],
    );
    final maxSeq = rows.first['max_seq'];
    if (maxSeq == null) return 0;
    return (maxSeq as int) + 1;
  }
}
