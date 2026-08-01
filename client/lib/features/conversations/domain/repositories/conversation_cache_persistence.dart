import 'package:sanad_client/features/conversations/domain/models/device_conversation_cache_snapshot.dart';

/// Persistence backend contract for the conversation cache.
///
/// Implementations must be cross-platform (desktop/web/mobile) and must NOT
/// store tokens, credentials, or raw transport payloads. They persist only the
/// snapshots needed to rebuild the sidebar after restart: workspaces,
/// conversation page summaries, expansion preferences, last selected session,
/// and drafts.
///
/// All keys are namespaced and versioned so a schema migration or invalidation
/// can run without crashing the app on an old payload.
abstract class ConversationCachePersistence {
  /// Load the full persisted snapshot, migrating or invalidating as needed.
  Future<DeviceConversationCacheSnapshot> load();

  /// Persist the full snapshot (debounced writes are the caller's
  /// responsibility).
  Future<void> save(DeviceConversationCacheSnapshot snapshot);

  /// Remove all persisted keys for [deviceId].
  Future<void> clearDevice(String deviceId);

  /// Remove cloud-user-scoped data while preserving local desktop inventory.
  Future<void> clearCloudUserScope(Set<String> cloudDeviceIds);

  /// Remove all persisted conversation cache keys (e.g. on full reset).
  Future<void> clearAll();
}
