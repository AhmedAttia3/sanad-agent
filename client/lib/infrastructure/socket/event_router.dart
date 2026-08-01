import 'dart:async';

/// Routes incoming events to device-scoped streams.
class EventRouter {
  final Map<String, StreamController<Map<String, dynamic>>> _deviceStreams = {};

  /// Get or create a stream for a specific backend device.
  Stream<Map<String, dynamic>> forDevice(String deviceId) {
    _deviceStreams.putIfAbsent(deviceId, () => StreamController<Map<String, dynamic>>.broadcast());
    return _deviceStreams[deviceId]!.stream;
  }

  /// Route an event to its device stream. Events without device_id are ignored.
  void routeEvent(Map<String, dynamic> event) {
    final deviceId = event['device_id'] as String?;
    if (deviceId != null && deviceId.isNotEmpty) {
      _deviceStreams.putIfAbsent(deviceId, () => StreamController<Map<String, dynamic>>.broadcast());
      _deviceStreams[deviceId]!.add(event);
    }
  }

  void dispose() {
    for (final controller in _deviceStreams.values) {
      unawaited(controller.close());
    }
    _deviceStreams.clear();
  }
}
