import 'package:equatable/equatable.dart';

import 'session.dart';
import 'conversation_resource_state.dart';

/// A workspace-scoped or unscoped conversation group ready for sidebar
/// rendering.
///
/// The store produces a flat list of [SidebarConversationGroup]s from the
/// cached pages so the sidebar widget does not perform pagination merges,
/// cursor arithmetic, or state filtering itself. Each group already reflects
/// the correct lifecycle state and whether more pages can be loaded.
class SidebarConversationGroup extends Equatable {
  /// Non-null for workspace-scoped groups; null for the unscoped group.
  final String? workspaceId;
  final String? workspaceName;
  final String? workspacePath;

  /// Sessions in display order (already merged, deduplicated, re-sorted).
  final List<Session> sessions;

  final ConversationResourceState state;
  final bool hasMore;
  final bool isLoadingMore;

  const SidebarConversationGroup({
    required this.workspaceId,
    required this.workspaceName,
    required this.workspacePath,
    required this.sessions,
    required this.state,
    required this.hasMore,
    required this.isLoadingMore,
  });

  bool get isUnscoped => workspaceId == null;

  @override
  List<Object?> get props => [
    workspaceId,
    workspaceName,
    workspacePath,
    sessions,
    state,
    hasMore,
    isLoadingMore,
  ];
}
