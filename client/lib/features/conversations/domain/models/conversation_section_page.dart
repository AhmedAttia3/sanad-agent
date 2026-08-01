import 'package:equatable/equatable.dart';

import 'session.dart';
import 'conversation_resource_state.dart';

/// A versioned, cursor-aware page of sessions for one conversation section.
///
/// A "section" is either the unscoped conversation list for a device, or the
/// conversation list scoped to a single `workspaceId`. The store merges
/// overlapping pages by `deviceId + sessionId` identity and keeps server
/// ordering stable. [ConversationSectionPage] is an immutable snapshot of one
/// merged section at a point in time.
class ConversationSectionPage extends Equatable {
  /// Sessions ordered by `last_user_message_at` descending with a stable
  /// tie-breaker. The store owns this ordering; callers must not re-sort.
  final List<Session> sessions;

  /// Opaque cursor returned by the daemon for the next page, if any.
  final String? nextCursor;

  /// Whether the daemon reported more pages exist beyond [sessions].
  final bool hasMore;

  /// Lifecycle phase of this section (see [ConversationResourceState]).
  final ConversationResourceState state;

  /// Wall-clock time of the last successful daemon refresh.
  final DateTime? lastRefreshedAt;

  /// Wall-clock time of the last failed refresh, when [state] is [staleError].
  final DateTime? lastErrorAt;

  /// Human-readable detail for the last failure, when known.
  final String? lastError;

  const ConversationSectionPage({
    required this.sessions,
    required this.nextCursor,
    required this.hasMore,
    required this.state,
    required this.lastRefreshedAt,
    required this.lastErrorAt,
    required this.lastError,
  });

  /// An empty section that has never been loaded.
  factory ConversationSectionPage.notLoaded() => const ConversationSectionPage(
    sessions: [],
    nextCursor: null,
    hasMore: false,
    state: ConversationResourceState.notLoaded,
    lastRefreshedAt: null,
    lastErrorAt: null,
    lastError: null,
  );

  ConversationSectionPage copyWith({
    List<Session>? sessions,
    String? nextCursor,
    bool? hasMore,
    ConversationResourceState? state,
    DateTime? lastRefreshedAt,
    DateTime? lastErrorAt,
    String? lastError,
    bool clearError = false,
    bool clearCursor = false,
  }) {
    return ConversationSectionPage(
      sessions: sessions ?? this.sessions,
      nextCursor: clearCursor ? null : (nextCursor ?? this.nextCursor),
      hasMore: hasMore ?? this.hasMore,
      state: state ?? this.state,
      lastRefreshedAt: lastRefreshedAt ?? this.lastRefreshedAt,
      lastErrorAt: lastErrorAt ?? this.lastErrorAt,
      lastError: clearError ? null : (lastError ?? this.lastError),
    );
  }

  @override
  List<Object?> get props => [
    sessions,
    nextCursor,
    hasMore,
    state,
    lastRefreshedAt,
    lastErrorAt,
    lastError,
  ];
}
