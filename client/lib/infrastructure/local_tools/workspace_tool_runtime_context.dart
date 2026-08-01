import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';

class WorkspaceToolRuntimeContext {
  DeviceWorkspace? _activeWorkspace;
  final Map<String, DeviceWorkspace> _workspaceBySessionId = {};
  final Map<String, Set<String>> _sessionPermissions = {};

  DeviceWorkspace? get activeWorkspace => _activeWorkspace;

  void setActiveWorkspace(DeviceWorkspace? workspace) {
    _activeWorkspace = workspace;
  }

  void bindSessionWorkspace(String sessionId, DeviceWorkspace workspace) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) {
      return;
    }

    _workspaceBySessionId[normalizedSessionId] = workspace;
    _activeWorkspace = workspace;
  }

  bool isAllowedForSession(String? sessionId, String approvalKey) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return false;
    }
    return _sessionPermissions[normalizedSessionId]?.contains(approvalKey) ?? false;
  }

  void allowForSession(String sessionId, String approvalKey) {
    final normalizedSessionId = sessionId.trim();
    if (normalizedSessionId.isEmpty) return;
    _sessionPermissions.putIfAbsent(normalizedSessionId, () => {}).add(approvalKey);
  }

  void unbindSession(String sessionId) {
    final normalizedSessionId = sessionId.trim();
    _workspaceBySessionId.remove(normalizedSessionId);
    _sessionPermissions.remove(normalizedSessionId);
  }

  DeviceWorkspace? workspaceForSession(String? sessionId) {
    final normalizedSessionId = sessionId?.trim();
    if (normalizedSessionId == null || normalizedSessionId.isEmpty) {
      return _activeWorkspace;
    }
    return _workspaceBySessionId[normalizedSessionId] ?? _activeWorkspace;
  }

  void clear() {
    _activeWorkspace = null;
    _workspaceBySessionId.clear();
    _sessionPermissions.clear();
  }
}
