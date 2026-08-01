import 'session.dart';

class SessionQueryRequest {
  final String? workspaceId;
  final bool unscopedOnly;
  final int? limit;
  final String? cursor;

  SessionQueryRequest({
    this.workspaceId,
    this.unscopedOnly = false,
    this.limit,
    this.cursor,
  });

  bool get isDefault =>
      (workspaceId == null || workspaceId!.trim().isEmpty) && !unscopedOnly && limit == null && cursor == null;

  String get cacheKey => [
    workspaceId?.trim() ?? '',
    unscopedOnly ? '1' : '0',
    limit?.toString() ?? '',
    cursor ?? '',
  ].join('|');

  Map<String, dynamic> toJson() {
    return {
      if (workspaceId != null && workspaceId!.trim().isNotEmpty) 'workspace_id': workspaceId!.trim(),
      if (unscopedOnly) 'unscoped_only': true,
      if (limit != null) 'limit': limit,
      if (cursor != null) 'cursor': cursor,
    };
  }
}

class SessionQueryResult {
  final List<Session> sessions;
  final String? nextCursor;
  final bool hasMore;

  SessionQueryResult({
    required this.sessions,
    this.nextCursor,
    required this.hasMore,
  });

  factory SessionQueryResult.fromJson(Map<String, dynamic> json) {
    final rawSessions = json['sessions'] as List?;
    final sessions = rawSessions != null
        ? rawSessions.map((s) => Session.fromJson(Map<String, dynamic>.from(s))).toList()
        : <Session>[];
    return SessionQueryResult(
      sessions: sessions,
      nextCursor: json['next_cursor']?.toString(),
      hasMore: json['has_more'] == true,
    );
  }
}
