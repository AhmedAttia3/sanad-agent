/// Canonical route path constants for the Sanad client.
///
/// All route strings are defined here. Features must reference these constants
/// and never hardcode route strings.
class AppRoutes {
  AppRoutes._();

  // ── Auth / Bootstrap ──────────────────────────────────────────────────────

  static const splash = '/';
  static const login = '/login';
  static const onboarding = '/onboarding';

  // ── Home / Conversations ──────────────────────────────────────────────────

  static const home = '/home';

  /// Device conversation list: /conversations/:deviceId
  static const conversations = '/conversations/:deviceId';

  /// Specific session: /conversations/:deviceId/:sessionId
  static const session = '/conversations/:deviceId/:sessionId';

  /// New Conversation for a device: /conversations/:deviceId/new
  static const newConversation = '/conversations/:deviceId/new';

  // ── Settings ──────────────────────────────────────────────────────────────

  static const settings = '/settings';
  static const stdioMcpSettings = '/settings/mcp/stdio';
  static const mcpServers = '/settings/mcp/servers';
  static const addMcpServer = '/settings/mcp/servers/add';

  // ── Devices ───────────────────────────────────────────────────────────────

  static const agents = '/agents';
  static const addAgent = '/devices/add';

  // ── Error ─────────────────────────────────────────────────────────────────

  static const notFound = '/not-found';

  // ── Route Builders ────────────────────────────────────────────────────────

  /// Build a route string for a device conversation list.
  static String conversationLocation(String deviceId) => Uri(
    pathSegments: ['', 'conversations', deviceId],
  ).toString();

  /// Build a route string for a specific session.
  static String sessionLocation(String deviceId, String sessionId) => Uri(
    pathSegments: ['', 'conversations', deviceId, sessionId],
  ).toString();

  /// Build a route string for New Conversation for a device.
  static String workspaceSettingsLocation(
    String deviceId,
    String workspaceId,
  ) => Uri(
    path: settings,
    queryParameters: {
      'section': 'workspace',
      'device_id': deviceId,
      'workspace_id': workspaceId,
    },
  ).toString();

  static String newConversationLocation(String deviceId, {String? workspaceId}) {
    return Uri(
      pathSegments: ['', 'conversations', deviceId, 'new'],
      queryParameters: workspaceId != null && workspaceId.isNotEmpty ? {'workspace': workspaceId} : null,
    ).toString();
  }
}
