import 'package:equatable/equatable.dart';

import 'device_workspace.dart';
import 'sidebar_conversation_group.dart';

/// Sidebar view-model derived from the device cache snapshot.
///
/// This is what the sidebar widget observes: device identity, the workspace
/// list with expansion state, and the ready-to-render conversation groups. The
/// store assembles it from [DeviceConversationContext] so widgets never touch
/// cursors, serialization, or pagination merging.
class DeviceSidebarSnapshot extends Equatable {
  final String deviceId;
  final List<DeviceWorkspace> workspaces;
  final Map<String, bool> workspaceExpansion;
  final List<SidebarConversationGroup> conversationGroups;

  const DeviceSidebarSnapshot({
    required this.deviceId,
    required this.workspaces,
    required this.workspaceExpansion,
    required this.conversationGroups,
  });

  @override
  List<Object?> get props => [
    deviceId,
    workspaces,
    workspaceExpansion,
    conversationGroups,
  ];
}
