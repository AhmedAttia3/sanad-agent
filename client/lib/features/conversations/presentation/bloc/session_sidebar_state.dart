import 'package:equatable/equatable.dart';

import '../../domain/models/conversation_resource_state.dart';
import '../../domain/models/device_sidebar_snapshot.dart';
import '../../domain/models/sidebar_conversation_group.dart';

/// View-model state for the redesigned device workspace sidebar (Plan 32c).
///
/// This state derives from `ConversationCacheRepository` (Plan 32b). It carries
/// only presentation data: the active device, the cached sidebar snapshot for
/// that device, and the transient refresh status that overlays cache while a
/// background revalidation is running. The sidebar widget never owns cache
/// maps, pagination cursors, or drafts.
class SessionSidebarState extends Equatable {
  /// The device id the sidebar is currently scoped to. May be null transiently
  /// during bootstrap before a device is selected.
  final String? activeDeviceId;

  /// Ready-to-render sidebar view-model assembled by the cache store. Null when
  /// no device context has been hydrated yet; widgets render an empty/loading
  /// state in that case.
  final DeviceSidebarSnapshot? snapshot;

  /// Per-workspace conversation lifecycle, keyed by workspace id. The null key
  /// represents the unscoped conversations section. This is a thin overlay for
  /// rendering section affordances (spinner / load more / retry) and never
  /// duplicates cache ownership.
  final Map<String?, ConversationResourceState> sectionStates;

  /// Per-section load-more flags, keyed by workspace id (null = unscoped).
  final Set<String?> loadingMoreSections;

  /// Workspace-list resource state, used to drive the Workspaces header chrome.
  final ConversationResourceState workspacesState;

  /// Whether a full sidebar refresh is in flight for the active device.
  final bool isRefreshing;

  /// Whether the first load for the active device has not yet produced any
  /// usable snapshot (notLoaded across every section). The sidebar renders a
  /// centered spinner instead of empty section bodies in that case only.
  final bool showInitialLoading;

  const SessionSidebarState({
    this.activeDeviceId,
    this.snapshot,
    this.sectionStates = const {},
    this.loadingMoreSections = const {},
    this.workspacesState = ConversationResourceState.notLoaded,
    this.isRefreshing = false,
    this.showInitialLoading = true,
  });

  /// Expansion state for a workspace id, defaulting to expanded (Plan 32c §السلوك).
  bool isWorkspaceExpanded(String? workspaceId) {
    if (workspaceId == null) return true;
    return snapshot?.workspaceExpansion[workspaceId] ?? true;
  }

  /// The unscoped group (Conversations section), or null if not available.
  SidebarConversationGroup? get unscopedGroup {
    final groups = snapshot?.conversationGroups ?? const [];
    for (final group in groups) {
      if (group.isUnscoped) return group;
    }
    return null;
  }

  /// Workspace-scoped groups in display order.
  List<SidebarConversationGroup> get workspaceGroups {
    final groups = snapshot?.conversationGroups ?? const [];
    return groups.where((group) => !group.isUnscoped).toList(growable: false);
  }

  /// Lifecycle state for a section (workspace id or null for unscoped).
  ConversationResourceState sectionState(String? workspaceId) {
    return sectionStates[workspaceId] ?? ConversationResourceState.notLoaded;
  }

  /// Whether a section is actively loading more pages.
  bool isSectionLoadingMore(String? workspaceId) => loadingMoreSections.contains(workspaceId);

  SessionSidebarState copyWith({
    String? activeDeviceId,
    bool clearActiveDevice = false,
    DeviceSidebarSnapshot? snapshot,
    bool clearSnapshot = false,
    Map<String?, ConversationResourceState>? sectionStates,
    Set<String?>? loadingMoreSections,
    ConversationResourceState? workspacesState,
    bool? isRefreshing,
    bool? showInitialLoading,
  }) {
    return SessionSidebarState(
      activeDeviceId: clearActiveDevice ? null : (activeDeviceId ?? this.activeDeviceId),
      snapshot: clearSnapshot ? null : (snapshot ?? this.snapshot),
      sectionStates: sectionStates ?? this.sectionStates,
      loadingMoreSections: loadingMoreSections ?? this.loadingMoreSections,
      workspacesState: workspacesState ?? this.workspacesState,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      showInitialLoading: showInitialLoading ?? this.showInitialLoading,
    );
  }

  @override
  List<Object?> get props => [
    activeDeviceId,
    snapshot,
    sectionStates,
    loadingMoreSections,
    workspacesState,
    isRefreshing,
    showInitialLoading,
  ];
}
