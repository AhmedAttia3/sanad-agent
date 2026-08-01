import 'dart:io';

import 'package:sanad_agent/capabilities/mcp/sanad_settings_store.dart';

import 'workspace_policy.dart';

class WorkspacePolicyStore {
  const WorkspacePolicyStore({
    SanadSettingsStore settingsStore = const SanadSettingsStore(),
  }) : _settingsStore = settingsStore;

  final SanadSettingsStore _settingsStore;

  Future<WorkspacePolicy> readPolicy(String workspacePath) async {
    return _settingsStore.readWorkspacePolicy(workspacePath);
  }

  Future<void> savePolicy(String workspacePath, WorkspacePolicy policy) async {
    await _settingsStore.saveWorkspacePolicy(workspacePath, policy);
  }

  Future<void> savePermissionMode(
    String workspacePath,
    WorkspacePermissionMode permissionMode,
  ) async {
    final current = await readPolicy(workspacePath);
    if (current.permissionMode == permissionMode) {
      return;
    }
    await savePolicy(
      workspacePath,
      current.copyWith(permissionMode: permissionMode),
    );
  }

  static Directory sanadDirectoryForWorkspace(String workspacePath) {
    return SanadSettingsStore.sanadDirectoryForWorkspace(workspacePath);
  }

  static File settingsFileForWorkspace(String workspacePath) {
    return SanadSettingsStore.settingsFileForWorkspace(workspacePath);
  }
}
