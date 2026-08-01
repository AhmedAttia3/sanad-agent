import 'package:equatable/equatable.dart';

import 'device_conversation_context.dart';
import 'conversation_draft.dart';

/// Root immutable snapshot of the entire client conversation cache.
///
/// Exposed to cubits and widgets as the single source of truth for device
/// switching, sidebar rendering, and drafts. Widgets never read the
/// persistence layer or serialization directly.
class DeviceConversationCacheSnapshot extends Equatable {
  /// Currently selected device. Switching it is atomic: the store emits a new
  /// snapshot whose [contexts] still contains the previous device's cache, but
  /// only the [activeDeviceId] slice is rendered.
  final String? activeDeviceId;

  /// Per-device cache slices.
  final Map<String, DeviceConversationContext> contexts;

  /// Drafts for existing sessions, keyed by `deviceId + sessionId`.
  final Map<String, ConversationDraft> sessionDrafts;

  /// Last manually viewed event per session, keyed by `deviceId + sessionId`.
  ///
  /// Event identity survives responsive layout changes that would invalidate a
  /// persisted pixel offset.
  final Map<String, String> sessionViewportAnchors;

  const DeviceConversationCacheSnapshot({
    required this.activeDeviceId,
    required this.contexts,
    required this.sessionDrafts,
    this.sessionViewportAnchors = const {},
  });

  factory DeviceConversationCacheSnapshot.empty() => const DeviceConversationCacheSnapshot(
    activeDeviceId: null,
    contexts: {},
    sessionDrafts: {},
    sessionViewportAnchors: {},
  );

  /// The cache slice for the active device, or an empty context if none.
  DeviceConversationContext get activeContext => activeDeviceId == null
      ? DeviceConversationContext.empty()
      : (contexts[activeDeviceId] ?? DeviceConversationContext.empty());

  /// Composite key for session-owned client state: `deviceId|sessionId`.
  static String sessionKey(String deviceId, String sessionId) => '$deviceId|$sessionId';

  /// Composite key for a session draft: `deviceId|sessionId`.
  static String sessionDraftKey(String deviceId, String sessionId) => sessionKey(deviceId, sessionId);

  /// Composite key for a session viewport anchor: `deviceId|sessionId`.
  static String sessionViewportKey(String deviceId, String sessionId) => sessionKey(deviceId, sessionId);

  /// Composite key for the New Conversation draft: `deviceId|__new__`.
  static String newConversationDraftKey(String deviceId) => '$deviceId|__new__';

  @override
  List<Object?> get props => [
    activeDeviceId,
    contexts,
    sessionDrafts,
    sessionViewportAnchors,
  ];
}
