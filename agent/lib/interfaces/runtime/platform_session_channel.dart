import 'dart:async';

/// Abstract interface representing a communication channel to the client platform
/// for sending protocol events (e.g. tool permission requests, platform tool calls).
abstract class PlatformSessionChannel {
  /// Sends a protocol event to the platform.
  Future<void> sendProtocolEvent(
    String eventType,
    Map<String, dynamic> payload,
  );
}
