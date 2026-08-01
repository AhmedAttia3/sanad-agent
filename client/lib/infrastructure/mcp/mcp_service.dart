import 'dart:async';

class McpService {
  McpService({
    dynamic workspaceRuntimeContext,
    dynamic settingsStore,
  });

  Future<void> init() async {
    // No-op: Local MCP process execution moved to the daemon
  }

  void dispose() {
    // No-op: Local MCP process execution moved to the daemon
  }
}
