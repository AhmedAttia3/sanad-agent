import 'dart:async';

import 'package:sanad_client/features/conversations/domain/models/device_processing_snapshot.dart';

class ProcessingStore {
  final _controller = StreamController<Map<String, DeviceProcessingSnapshot>>.broadcast();
  final Map<String, DeviceProcessingSnapshot> _snapshotsByAgentId = {};

  Stream<Map<String, DeviceProcessingSnapshot>> get stream => _controller.stream;
  Map<String, DeviceProcessingSnapshot> get snapshotsByAgentId => Map.unmodifiable(_snapshotsByAgentId);

  DeviceProcessingSnapshot snapshotForAgent(String deviceId) {
    return _snapshotsByAgentId[deviceId] ?? const DeviceProcessingSnapshot();
  }

  Map<String, Set<String>> get processingSessionIdsByAgentId {
    final result = <String, Set<String>>{};
    for (final entry in _snapshotsByAgentId.entries) {
      if (entry.value.sessionIds.isNotEmpty) {
        result[entry.key] = Set.unmodifiable(entry.value.sessionIds);
      }
    }
    return Map.unmodifiable(result);
  }

  void setSnapshot(String deviceId, DeviceProcessingSnapshot snapshot) {
    final previous = snapshotForAgent(deviceId);
    if (_snapshotsEqual(previous, snapshot)) {
      return;
    }
    _snapshotsByAgentId[deviceId] = snapshot;
    _emit();
  }

  void clearAgent(String deviceId) {
    if (_snapshotsByAgentId.remove(deviceId) != null) {
      _emit();
    }
  }

  void retainAgents(Set<String> deviceIds) {
    final before = _snapshotsByAgentId.length;
    _snapshotsByAgentId.removeWhere((deviceId, _) => !deviceIds.contains(deviceId));
    if (before != _snapshotsByAgentId.length) {
      _emit();
    }
  }

  void clear() {
    if (_snapshotsByAgentId.isEmpty) return;
    _snapshotsByAgentId.clear();
    _emit();
  }

  bool _snapshotsEqual(DeviceProcessingSnapshot a, DeviceProcessingSnapshot b) {
    return a.isDraftProcessing == b.isDraftProcessing &&
        a.sessionIds.length == b.sessionIds.length &&
        a.sessionIds.containsAll(b.sessionIds);
  }

  void _emit() {
    if (!_controller.isClosed) {
      _controller.add(snapshotsByAgentId);
    }
  }

  void dispose() {
    unawaited(_controller.close());
  }
}
