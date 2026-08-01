/// A typed navigation destination within the Conversation domain.
///
/// Every conversation route resolves to exactly one [ConversationDestination].
/// Use [ConversationDestination.newConversation] for the "New Conversation"
/// surface, [ConversationDestination.session] for an existing session, and
/// [ConversationDestination.conversationsList] for the device-level listing
/// without a specific session.
///
/// ## Route identity
///
/// Two destinations are equal if they share the same [kind], [deviceId],
/// [sessionId] (or New Conversation sentinel), and optional [workspaceId].
/// This identity is stable: it does not depend on runtime state, so it can be
/// compared across route parsing, history entries, and device reconciliation.
///
/// ## New Conversation marker
///
/// [sessionId] is `null` for a New Conversation destination (no session
/// exists yet). The route string uses the reserved `new` path marker rather
/// than a real session id. [isNewConversation] is the canonical check — never compare
/// [sessionId] to a literal sentinel string.
///
/// ## URL pattern
///
///   /conversations/:deviceId                    — device conversation list
///   /conversations/:deviceId/:sessionId         — specific session
///   /conversations/:deviceId/new                — new conversation for device
///   /conversations/:deviceId/new?workspace=:id  — new conversation with workspace
///
class ConversationDestination {
  /// The kind of destination this represents.
  final ConversationDestinationKind kind;

  /// The device that owns (or will own) the conversation.
  final String deviceId;

  /// The session id, or `null` when [kind] is [ConversationDestinationKind.newConversation].
  final String? sessionId;

  /// An optional workspace preselection for a new conversation.
  final String? workspaceId;

  const ConversationDestination._({
    required this.kind,
    required this.deviceId,
    this.sessionId,
    this.workspaceId,
  });

  /// Create a destination for an existing session.
  const ConversationDestination.session({
    required String deviceId,
    required String sessionId,
    String? workspaceId,
  }) : this._(
         kind: ConversationDestinationKind.session,
         deviceId: deviceId,
         sessionId: sessionId,
         workspaceId: workspaceId,
       );

  /// Create a destination for the New Conversation surface.
  const ConversationDestination.newConversation({
    required String deviceId,
    String? workspaceId,
  }) : this._(
         kind: ConversationDestinationKind.newConversation,
         deviceId: deviceId,
         sessionId: null,
         workspaceId: workspaceId,
       );

  /// Create a destination for the device conversation list (no session).
  const ConversationDestination.conversationsList({
    required String deviceId,
  }) : this._(
         kind: ConversationDestinationKind.conversationsList,
         deviceId: deviceId,
         sessionId: null,
         workspaceId: null,
       );

  // ---------------------------------------------------------------------------
  // Accessors
  // ---------------------------------------------------------------------------

  bool get isNewConversation => kind == ConversationDestinationKind.newConversation;

  bool get isSession => kind == ConversationDestinationKind.session;

  bool get isConversationsList => kind == ConversationDestinationKind.conversationsList;

  // ---------------------------------------------------------------------------
  // Route helpers
  // ---------------------------------------------------------------------------

  /// Canonical URL path for this destination.
  String get routePath {
    switch (kind) {
      case ConversationDestinationKind.conversationsList:
        return Uri(
          pathSegments: ['', 'conversations', deviceId],
        ).toString();
      case ConversationDestinationKind.newConversation:
        return Uri(
          pathSegments: ['', 'conversations', deviceId, 'new'],
          queryParameters: workspaceId != null && workspaceId!.isNotEmpty ? {'workspace': workspaceId!} : null,
        ).toString();
      case ConversationDestinationKind.session:
        return Uri(
          pathSegments: ['', 'conversations', deviceId, sessionId!],
        ).toString();
    }
  }

  /// Parse a [ConversationDestination] from GoRouter path parameters and query
  /// parameters. Returns `null` if the parameters do not match a known pattern.
  static ConversationDestination? fromRouteParams({
    required String? deviceId,
    required String? sessionId,
    required Map<String, String>? queryParameters,
    bool isNew = false,
  }) {
    if (deviceId == null || deviceId.isEmpty) return null;

    // Explicit New Conversation (session is "new" sentinel path segment or isNew is true)
    if (sessionId == 'new' || isNew) {
      final workspaceId = queryParameters?['workspace'];
      if (workspaceId != null && workspaceId.isEmpty) {
        return ConversationDestination.newConversation(deviceId: deviceId);
      }
      return ConversationDestination.newConversation(
        deviceId: deviceId,
        workspaceId: workspaceId,
      );
    }

    // Existing session
    if (sessionId != null && sessionId.isNotEmpty) {
      // Guard: "new" is already handled above; any other non-empty is a session id.
      return ConversationDestination.session(
        deviceId: deviceId,
        sessionId: sessionId,
      );
    }

    // Device conversation list
    return ConversationDestination.conversationsList(deviceId: deviceId);
  }

  // ---------------------------------------------------------------------------
  // Equality
  // ---------------------------------------------------------------------------

  @override
  bool operator ==(Object other) {
    if (other is! ConversationDestination) return false;
    return kind == other.kind &&
        deviceId == other.deviceId &&
        sessionId == other.sessionId &&
        workspaceId == other.workspaceId;
  }

  @override
  int get hashCode => Object.hash(kind, deviceId, sessionId, workspaceId);

  @override
  String toString() =>
      'ConversationDestination($kind, deviceId=$deviceId, sessionId=$sessionId, workspaceId=$workspaceId)';
}

/// The kind of a [ConversationDestination].
enum ConversationDestinationKind {
  /// An existing conversation session.
  session,

  /// The "New Conversation" surface (no session yet).
  newConversation,

  /// The device-level conversation list without a specific session/NewConversation.
  conversationsList,
}
