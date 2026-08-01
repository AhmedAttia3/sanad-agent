import 'session_state.dart';

class SessionQueryRequest {
  static const int defaultLimit = 10;
  static const int maxLimit = 100;

  final String? workspaceId;
  final bool unscopedOnly;
  final int limit;
  final String? cursor;

  SessionQueryRequest({
    this.workspaceId,
    this.unscopedOnly = false,
    this.limit = defaultLimit,
    this.cursor,
  }) {
    final wId = workspaceId;
    if (wId != null && wId.trim().isNotEmpty && unscopedOnly) {
      throw ArgumentError(
        'workspace_id and unscoped_only cannot be used together.',
      );
    }
    if (limit <= 0) {
      throw ArgumentError('limit must be greater than zero.');
    }
  }

  factory SessionQueryRequest.fromMap(Map<String, dynamic> map) {
    final limitVal = map['limit'];
    var parsedLimit = defaultLimit;
    if (limitVal == null) {
      parsedLimit = defaultLimit;
    } else if (limitVal is int) {
      parsedLimit = limitVal;
    } else if (limitVal is String) {
      parsedLimit =
          int.tryParse(limitVal) ??
          (throw ArgumentError('limit must be an integer.'));
    } else {
      throw ArgumentError('limit must be an integer.');
    }

    if (parsedLimit <= 0) {
      throw ArgumentError('limit must be greater than zero.');
    }

    return SessionQueryRequest(
      workspaceId: map['workspace_id']?.toString(),
      unscopedOnly:
          map['unscoped_only'] == true || map['unscoped_only'] == 'true',
      limit: parsedLimit > maxLimit ? maxLimit : parsedLimit,
      cursor: map['cursor']?.toString(),
    );
  }
}

class SessionQueryResult {
  final List<SessionState> sessions;
  final String? nextCursor;
  final bool hasMore;

  SessionQueryResult({
    required this.sessions,
    this.nextCursor,
    required this.hasMore,
  });
}
