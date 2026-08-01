import 'dart:async';

import 'package:sanad_client/features/conversations/domain/models/device_conversation_cache_snapshot.dart';
import 'package:sanad_client/features/conversations/domain/repositories/conversation_cache_persistence.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';

/// Coordinates debounced persistence of [ConversationCacheStore] snapshots.
///
/// Draft text and frequent mutations are debounced so we do not write to disk
/// on every keystroke. [flush] is called on lifecycle pause/close so the last
/// edit is never lost (Plan 32 §"قواعد persistence").
class ConversationCachePersistor {
  final ConversationCacheStore _store;
  final ConversationCachePersistence _persistence;
  final Duration debounceDuration;

  StreamSubscription<DeviceConversationCacheSnapshot>? _subscription;
  Timer? _debounceTimer;
  bool _loaded = false;
  Future<void> _writeQueue = Future<void>.value();

  ConversationCachePersistor({
    required ConversationCacheStore store,
    required ConversationCachePersistence persistence,
    this.debounceDuration = const Duration(milliseconds: 500),
  }) : _store = store,
       _persistence = persistence;

  /// Load the persisted snapshot into the store. Call once at startup before
  /// subscribing widget consumers.
  Future<void> hydrate() async {
    if (_loaded) return;
    _loaded = true;
    final snapshot = await _persistence.load();
    _applySnapshotToStore(snapshot);
    _subscription = _store.snapshotStream.listen(_onSnapshotChanged);
  }

  void _applySnapshotToStore(DeviceConversationCacheSnapshot snapshot) {
    // Restore active device and per-device contexts/drafts without emitting
    // intermediate states. We do this by directly seeding the store through its
    // public API in one batch.
    for (final entry in snapshot.contexts.entries) {
      _store.ensureDeviceContext(entry.key);
    }
    // The store exposes granular setters; but to avoid re-implementing a bulk
    // loader we rely on the store's own restore method when present. Here we
    // only restore active device + drafts; full page restoration is done via
    // [ConversationCacheStore.restoreFromSnapshot].
    _store.restoreFromSnapshot(snapshot);
  }

  void _onSnapshotChanged(DeviceConversationCacheSnapshot snapshot) {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, () {
      unawaited(_persist(snapshot).catchError((_) {}));
    });
  }

  Future<void> _persist(DeviceConversationCacheSnapshot snapshot) async {
    final operation = _writeQueue.then((_) => _persistence.save(snapshot));
    _writeQueue = operation.catchError((_) {});
    await operation;
  }

  /// Flush any pending debounced write immediately. Call on lifecycle pause
  /// or close so the last edit survives.
  Future<void> flush() async {
    _debounceTimer?.cancel();
    await _persist(_store.snapshot);
  }

  Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
    _debounceTimer?.cancel();
    await flush();
  }
}
