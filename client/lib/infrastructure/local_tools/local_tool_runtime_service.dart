import 'dart:async';

class LocalToolRuntimeService {
  LocalToolRuntimeService({
    dynamic mcpService,
    dynamic workspaceRuntimeContext,
    dynamic workspacePolicyStore,
    dynamic toolApprovalService,
    dynamic prefs,
    dynamic webSearchService,
    dynamic webFetchService,
    dynamic conversationRepository,
    dynamic deviceRepository,
  });

  Future<void> broadcastAvailableTools({String? workspaceId}) async {
    // No-op: Platform tool execution moved to the daemon
  }

  Future<void> handleToolExecutionRequest(Map<String, dynamic> data) async {
    // No-op: Platform tool execution moved to the daemon
  }
}
