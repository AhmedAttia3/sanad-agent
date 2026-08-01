import 'dart:async';

import 'package:sanad_agent/interfaces/runtime/platform_session_channel.dart';

class CloudSessionChannel implements PlatformSessionChannel {
  final Future<void> Function(Map<String, dynamic> envelope) onSend;
  final String? deviceId;

  CloudSessionChannel({required this.onSend, this.deviceId});

  @override
  Future<void> sendProtocolEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    final sessionId = payload['session_id'];
    final envelope = {
      'message_type': 'event',
      'type': 'device_event',
      'event': eventType,
      'payload': payload,
      'session_id': sessionId,
      if (payload['request_id'] != null) 'request_id': payload['request_id'],
      // Phase 27: preserve canonical identity across transports.
      if (payload['event_id'] != null) 'event_id': payload['event_id'],
      if (payload['delivery'] is Map<String, dynamic>)
        'delivery': payload['delivery'],
    };
    await onSend(envelope);
  }
}
