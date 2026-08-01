import 'dart:convert';
import 'dart:io';

import 'package:sanad_agent/interfaces/runtime/platform_session_channel.dart';

class WebSocketSessionChannel implements PlatformSessionChannel {
  final WebSocket socket;
  final String? deviceId;

  WebSocketSessionChannel(this.socket, {this.deviceId});

  @override
  Future<void> sendProtocolEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    final sessionId = payload['session_id'];
    final envelope = {
      'message_type': 'event',
      'type': 'device_event',
      if (deviceId != null) 'device_id': deviceId,
      'event': eventType,
      'payload': payload,
      'session_id': sessionId,
      if (payload['request_id'] != null) 'request_id': payload['request_id'],
      // Phase 27: preserve canonical identity across transports.
      if (payload['event_id'] != null) 'event_id': payload['event_id'],
      if (payload['delivery'] is Map<String, dynamic>)
        'delivery': payload['delivery'],
    };
    socket.add(jsonEncode(envelope));
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WebSocketSessionChannel && identical(socket, other.socket);

  @override
  int get hashCode => socket.hashCode;
}
