import 'package:equatable/equatable.dart';

import 'conversation_resource_state.dart';
import 'device_workspace.dart';

/// Snapshot of the cached workspace list for one device.
///
/// The daemon is authoritative; this is a display/recovery cache only. It is
/// refreshed via stale-while-revalidate: [state] tracks the lifecycle while
/// [workspaces] keeps the last known list so the sidebar renders instantly on
/// device switch or restart.
class CachedWorkspaceSection extends Equatable {
  final List<DeviceWorkspace> workspaces;
  final ConversationResourceState state;
  final DateTime? lastRefreshedAt;
  final DateTime? lastErrorAt;
  final String? lastError;

  const CachedWorkspaceSection({
    required this.workspaces,
    required this.state,
    required this.lastRefreshedAt,
    required this.lastErrorAt,
    required this.lastError,
  });

  factory CachedWorkspaceSection.notLoaded() => const CachedWorkspaceSection(
    workspaces: [],
    state: ConversationResourceState.notLoaded,
    lastRefreshedAt: null,
    lastErrorAt: null,
    lastError: null,
  );

  CachedWorkspaceSection copyWith({
    List<DeviceWorkspace>? workspaces,
    ConversationResourceState? state,
    DateTime? lastRefreshedAt,
    DateTime? lastErrorAt,
    String? lastError,
    bool clearError = false,
  }) {
    return CachedWorkspaceSection(
      workspaces: workspaces ?? this.workspaces,
      state: state ?? this.state,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
    workspaces,
    state,
    lastRefreshedAt,
    lastErrorAt,
    lastError,
  ];
}
