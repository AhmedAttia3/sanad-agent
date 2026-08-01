/// Resource lifecycle state for a cached conversation section.
///
/// Follows a stale-while-revalidate pattern: the UI renders a memory or
/// persistent snapshot immediately, then the store refreshes it from the
/// daemon in the background. Each [ConversationResourceState] captures the
/// phase of one resource (workspaces list, unscoped conversations, or a
/// per-workspace conversation page) so widgets can render correct affordances
/// (spinner, retry, "load more") without owning transport logic.
enum ConversationResourceState {
  /// No data has ever been loaded for this resource.
  notLoaded,

  /// First load in flight; no snapshot is available yet.
  loading,

  /// A snapshot exists and a background refresh is running.
  refreshing,

  /// A snapshot is available and no refresh is running.
  ready,

  /// The most recent refresh failed, but a (possibly stale) snapshot remains.
  staleError,
}

extension ConversationResourceStateX on ConversationResourceState {
  bool get hasUsableSnapshot =>
      this == ConversationResourceState.ready ||
      this == ConversationResourceState.refreshing ||
      this == ConversationResourceState.staleError;

  bool get isLoading => this == ConversationResourceState.loading || this == ConversationResourceState.refreshing;
}
