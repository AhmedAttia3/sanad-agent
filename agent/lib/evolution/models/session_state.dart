import '../../core/models/message.dart';

enum SessionTitleStatus {
  pending('pending'),
  finalized('final');

  final String wireValue;

  const SessionTitleStatus(this.wireValue);

  static SessionTitleStatus fromWire(Object? value) {
    return value == pending.wireValue ? pending : finalized;
  }
}

class SessionState {
  final String sessionId;
  final String model;
  final String? providerId;
  final String? thinkingMode;
  final String? title;
  final SessionTitleStatus titleStatus;
  final String? workspaceId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastUserMessageAt;
  final int routeRevision;
  final DateTime routeUpdatedAt;
  final List<Message> messages;

  SessionState({
    required this.sessionId,
    required this.model,
    this.providerId,
    this.thinkingMode,
    this.title,
    this.titleStatus = SessionTitleStatus.finalized,
    this.workspaceId,
    required this.createdAt,
    required this.updatedAt,
    this.lastUserMessageAt,
    this.routeRevision = 1,
    DateTime? routeUpdatedAt,
    this.messages = const [],
  }) : routeUpdatedAt = routeUpdatedAt ?? updatedAt;

  Map<String, dynamic> toMap() {
    return {
      'session_id': sessionId,
      'model': model,
      'provider_id': providerId,
      'thinking_mode': thinkingMode,
      'title': title,
      'title_status': titleStatus.wireValue,
      'workspace_id': workspaceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'last_user_message_at': lastUserMessageAt?.toIso8601String(),
      'route_revision': routeRevision,
      'route_updated_at': routeUpdatedAt.toIso8601String(),
    };
  }

  factory SessionState.fromMap(
    Map<String, dynamic> map, [
    List<Message> messages = const [],
  ]) {
    final lastUserMsgAtRaw = map['last_user_message_at'];
    return SessionState(
      sessionId: map['session_id'],
      model: map['model'],
      providerId: map['provider_id']?.toString(),
      thinkingMode: map['thinking_mode']?.toString(),
      title: map['title'],
      titleStatus: SessionTitleStatus.fromWire(map['title_status']),
      workspaceId: map['workspace_id']?.toString(),
      createdAt: DateTime.parse(map['created_at']),
      updatedAt: DateTime.parse(map['updated_at']),
      lastUserMessageAt: lastUserMsgAtRaw != null
          ? DateTime.parse(lastUserMsgAtRaw)
          : null,
      routeRevision: (map['route_revision'] as num?)?.toInt() ?? 1,
      routeUpdatedAt: DateTime.parse(
        map['route_updated_at']?.toString() ?? map['updated_at'].toString(),
      ),
      messages: messages,
    );
  }
}
