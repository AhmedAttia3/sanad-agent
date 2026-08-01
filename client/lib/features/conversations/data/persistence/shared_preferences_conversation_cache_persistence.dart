import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sanad_client/features/conversations/domain/models/device_conversation_cache_snapshot.dart';
import 'package:sanad_client/features/conversations/domain/models/device_conversation_context.dart';
import 'package:sanad_client/features/conversations/domain/models/conversation_draft.dart';
import 'package:sanad_client/features/conversations/domain/repositories/conversation_cache_persistence.dart';
import 'package:sanad_client/features/conversations/data/persistence/conversation_cache_codec.dart';

/// Cross-platform [ConversationCachePersistence] backed by [SharedPreferences].
///
/// SharedPreferences is available on desktop, web, and mobile, stores only
/// primitive JSON-encodable values (no binary blobs), and requires no secret
/// material. We persist a single namespaced JSON blob under a stable key; the
/// payload codec owns schema compatibility and invalidation.
///
/// The blob does NOT contain tokens, credentials, or raw transport payloads —
/// only sidebar-recovery snapshots and drafts (Plan 32 §"قواعد persistence").
class SharedPreferencesConversationCachePersistence implements ConversationCachePersistence {
  static const String _storageKey = 'sanad_conversation_cache';

  final SharedPreferences _prefs;
  final ConversationCacheCodec _codec;

  SharedPreferencesConversationCachePersistence(
    this._prefs, {
    ConversationCacheCodec codec = const ConversationCacheCodec(),
  }) : _codec = codec;

  @override
  Future<DeviceConversationCacheSnapshot> load() async {
    final raw = _prefs.getString(_storageKey);
    return _codec.decode(raw);
  }

  @override
  Future<void> save(DeviceConversationCacheSnapshot snapshot) async {
    final encoded = _codec.encode(snapshot);
    await _prefs.setString(_storageKey, encoded);
  }

  @override
  Future<void> clearDevice(String deviceId) async {
    final current = await load();
    final contexts = Map<String, DeviceConversationContext>.from(
      current.contexts,
    );
    contexts.remove(deviceId);
    final drafts = Map<String, ConversationDraft>.from(current.sessionDrafts);
    drafts.removeWhere((key, _) => key.startsWith('$deviceId|'));
    final next = DeviceConversationCacheSnapshot(
      activeDeviceId: current.activeDeviceId == deviceId ? null : current.activeDeviceId,
      contexts: contexts,
      sessionDrafts: drafts,
    );
    await save(next);
  }

  @override
  Future<void> clearCloudUserScope(Set<String> cloudDeviceIds) async {
    if (cloudDeviceIds.isEmpty) return;
    final current = await load();
    final contexts = Map<String, DeviceConversationContext>.from(
      current.contexts,
    );
    final drafts = Map<String, ConversationDraft>.from(current.sessionDrafts);
    String? activeDeviceId = current.activeDeviceId;
    for (final deviceId in cloudDeviceIds) {
      contexts.remove(deviceId);
      drafts.removeWhere((key, _) => key.startsWith('$deviceId|'));
      if (activeDeviceId == deviceId) activeDeviceId = null;
    }
    final next = DeviceConversationCacheSnapshot(
      activeDeviceId: activeDeviceId,
      contexts: contexts,
      sessionDrafts: drafts,
    );
    await save(next);
  }

  @override
  Future<void> clearAll() async {
    await _prefs.remove(_storageKey);
  }
}
