import 'package:equatable/equatable.dart';
import 'package:sanad_client/core/navigation/conversation_destination.dart';

import 'cached_workspace_section.dart';
import 'conversation_section_page.dart';

/// All cached conversation state owned by the store for a single device.
///
/// This is the per-device slice of the [DeviceConversationCacheSnapshot]
/// described in Plan 32 §4. It groups every resource the sidebar and New
/// Conversation surface need for one device so device switching is atomic and
/// never leaks another device's data.
class DeviceConversationContext extends Equatable {
  /// Exact typed destination restored after a client restart.
  final ConversationDestination? lastDestination;

  /// Most recently opened session, retained separately so New Conversation can
  /// inherit its provider/model context without changing the restored route.
  final String? lastSelectedSessionId;

  /// Cached workspace list for the device.
  final CachedWorkspaceSection workspaces;

  /// Unscoped conversation page (sessions with no `workspace_id`).
  final ConversationSectionPage unscopedConversations;

  /// Per-workspace conversation pages, keyed by `workspaceId`.
  final Map<String, ConversationSectionPage> workspaceConversationPages;

  /// Per-workspace expansion preference, keyed by `workspaceId`.
  final Map<String, bool> workspaceExpansion;

  /// Standalone New Conversation draft for this device.
  final String newConversationDraftText;
  final String? newConversationDraftWorkspaceId;
  final String? newConversationDraftProviderId;
  final String? newConversationDraftModel;
  final String? newConversationDraftThinkingMode;
  final String? newConversationDraftPermissionMode;
  final String? newConversationDraftPendingRequestId;
  final DateTime newConversationDraftUpdatedAt;

  const DeviceConversationContext({
    this.lastDestination,
    this.lastSelectedSessionId,
    required this.workspaces,
    required this.unscopedConversations,
    required this.workspaceConversationPages,
    required this.workspaceExpansion,
    required this.newConversationDraftText,
    required this.newConversationDraftWorkspaceId,
    required this.newConversationDraftProviderId,
    required this.newConversationDraftModel,
    required this.newConversationDraftThinkingMode,
    required this.newConversationDraftPermissionMode,
    required this.newConversationDraftPendingRequestId,
    required this.newConversationDraftUpdatedAt,
  });

  factory DeviceConversationContext.empty() => DeviceConversationContext(
    lastDestination: null,
    lastSelectedSessionId: null,
    workspaces: CachedWorkspaceSection.notLoaded(),
    unscopedConversations: ConversationSectionPage.notLoaded(),
    workspaceConversationPages: const {},
    workspaceExpansion: const {},
    newConversationDraftText: '',
    newConversationDraftWorkspaceId: null,
    newConversationDraftProviderId: null,
    newConversationDraftModel: null,
    newConversationDraftThinkingMode: null,
    newConversationDraftPermissionMode: null,
    newConversationDraftPendingRequestId: null,
    newConversationDraftUpdatedAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
  );

  DeviceConversationContext copyWith({
    ConversationDestination? lastDestination,
    String? lastSelectedSessionId,
    bool clearLastDestination = false,
    bool clearLastSelectedSession = false,
    CachedWorkspaceSection? workspaces,
    ConversationSectionPage? unscopedConversations,
    Map<String, ConversationSectionPage>? workspaceConversationPages,
    Map<String, bool>? workspaceExpansion,
    String? newConversationDraftText,
    String? newConversationDraftWorkspaceId,
    String? newConversationDraftProviderId,
    String? newConversationDraftModel,
    String? newConversationDraftThinkingMode,
    String? newConversationDraftPermissionMode,
    String? newConversationDraftPendingRequestId,
    DateTime? newConversationDraftUpdatedAt,
    bool clearNewConversationDraft = false,
    bool clearNewConversationDraftWorkspace = false,
    bool clearNewConversationDraftProvider = false,
    bool clearNewConversationDraftModel = false,
    bool clearNewConversationDraftThinkingMode = false,
    bool clearNewConversationDraftPermissionMode = false,
    bool clearNewConversationDraftPendingRequest = false,
  }) {
    return DeviceConversationContext(
      lastDestination: clearLastDestination ? null : (lastDestination ?? this.lastDestination),
      lastSelectedSessionId: clearLastSelectedSession ? null : (lastSelectedSessionId ?? this.lastSelectedSessionId),
      workspaces: workspaces ?? this.workspaces,
      unscopedConversations: unscopedConversations ?? this.unscopedConversations,
      workspaceConversationPages: workspaceConversationPages ?? this.workspaceConversationPages,
      workspaceExpansion: workspaceExpansion ?? this.workspaceExpansion,
      newConversationDraftText: clearNewConversationDraft
          ? ''
          : (newConversationDraftText ?? this.newConversationDraftText),
      newConversationDraftWorkspaceId: clearNewConversationDraft || clearNewConversationDraftWorkspace
          ? null
          : (newConversationDraftWorkspaceId ?? this.newConversationDraftWorkspaceId),
      newConversationDraftProviderId: clearNewConversationDraft || clearNewConversationDraftProvider
          ? null
          : (newConversationDraftProviderId ?? this.newConversationDraftProviderId),
      newConversationDraftModel: clearNewConversationDraft || clearNewConversationDraftModel
          ? null
          : (newConversationDraftModel ?? this.newConversationDraftModel),
      newConversationDraftThinkingMode: clearNewConversationDraft || clearNewConversationDraftThinkingMode
          ? null
          : (newConversationDraftThinkingMode ?? this.newConversationDraftThinkingMode),
      newConversationDraftPermissionMode: clearNewConversationDraft || clearNewConversationDraftPermissionMode
          ? null
          : (newConversationDraftPermissionMode ?? this.newConversationDraftPermissionMode),
      newConversationDraftPendingRequestId: clearNewConversationDraft || clearNewConversationDraftPendingRequest
          ? null
          : (newConversationDraftPendingRequestId ?? this.newConversationDraftPendingRequestId),
      newConversationDraftUpdatedAt: clearNewConversationDraft
          ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
          : (newConversationDraftUpdatedAt ?? this.newConversationDraftUpdatedAt),
    );
  }

  @override
  List<Object?> get props => [
    lastDestination,
    lastSelectedSessionId,
    workspaces,
    unscopedConversations,
    workspaceConversationPages,
    workspaceExpansion,
    newConversationDraftText,
    newConversationDraftWorkspaceId,
    newConversationDraftProviderId,
    newConversationDraftModel,
    newConversationDraftThinkingMode,
    newConversationDraftPermissionMode,
    newConversationDraftPendingRequestId,
    newConversationDraftUpdatedAt,
  ];
}
