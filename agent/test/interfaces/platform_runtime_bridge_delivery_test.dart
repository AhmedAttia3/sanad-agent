import 'dart:async';

import 'package:sanad_agent/interfaces/models/delivery/models.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart';
import 'package:sanad_agent/interfaces/runtime/platform_runtime_bridge.dart';
import 'package:sanad_agent/interfaces/runtime/platform_session_channel.dart';
import 'package:test/test.dart';

void main() {
  group('PlatformRuntimeBridge suspension delivery', () {
    test(
      'Sanad Client request bypasses last registered channel and resolves once',
      () async {
        final bridge = PlatformRuntimeBridge();
        final local = _RecordingChannel();
        final cloud = _RecordingChannel();
        final responses = <GatewayResponse>[];
        bridge
          ..registerSessionOrigin(
            'session-1',
            const OriginContext(
              platformFamily: PlatformFamily.sanadClient,
              transport: PlatformTransport.local,
              platformId: 'sanad-local',
              sessionId: 'session-1',
            ),
          )
          ..registerSessionClient('session-1', local, deviceId: 'device-1')
          ..registerSessionClient('session-1', cloud, deviceId: 'device-1')
          ..attachResponseSink(responses.add);

        final decisionFuture = bridge.requestToolPermission(
          sessionId: 'session-1',
          payload: const {
            'request_id': 'permission-1',
            'tool_name': 'system_ask_user',
            'question': 'Choose one',
          },
        );
        await Future<void>.delayed(Duration.zero);

        expect(local.events, isEmpty);
        expect(cloud.events, isEmpty);
        expect(responses, hasLength(1));
        expect(
          responses.single.message.metadata?['canonical_event_type'],
          CanonicalEventTypes.toolPermissionRequest,
        );
        expect(responses.single.delivery.scope, DeliveryScope.platformFamily);
        expect(
          responses.single.delivery.platformFamily,
          PlatformFamily.sanadClient,
        );

        expect(
          bridge.handleProtocolEvent(
            CanonicalEvent(
              type: CanonicalEventTypes.toolPermissionResponse,
              sessionId: 'session-1',
              payload: {
                'session_id': 'session-1',
                'request_id': 'permission-1',
                'allowed': true,
                'answer': 'First',
              },
            ),
          ),
          isTrue,
        );
        final decision = await decisionFuture;
        expect(decision['answer'], 'First');
        expect(
          (responses.last.message.metadata?['canonical_payload']
              as Map)['outcome'],
          'resolved',
        );

        expect(
          bridge.handleProtocolEvent(
            CanonicalEvent(
              type: CanonicalEventTypes.toolPermissionResponse,
              sessionId: 'session-1',
              payload: const {
                'session_id': 'session-1',
                'request_id': 'permission-1',
                'allowed': false,
                'answer': 'Second',
              },
            ),
          ),
          isTrue,
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          (responses.last.message.metadata?['canonical_payload']
              as Map)['outcome'],
          'already_resolved',
        );

        bridge
          ..registerSessionClient('session-1', cloud, deviceId: 'device-1')
          ..registerSessionClient('session-1', local, deviceId: 'device-1');
        final reverseOrderDecision = bridge.requestToolPermission(
          sessionId: 'session-1',
          payload: const {
            'request_id': 'permission-2',
            'tool_name': 'system_ask_user',
          },
        );
        await Future<void>.delayed(Duration.zero);
        expect(
          responses.last.message.metadata?['canonical_event_type'],
          CanonicalEventTypes.toolPermissionRequest,
        );
        bridge.handleProtocolEvent(
          CanonicalEvent(
            type: CanonicalEventTypes.toolPermissionResponse,
            sessionId: 'session-1',
            payload: const {
              'session_id': 'session-1',
              'request_id': 'permission-2',
              'allowed': true,
              'answer': 'Reverse order',
            },
          ),
        );
        expect((await reverseOrderDecision)['answer'], 'Reverse order');
        expect(local.events, isEmpty);
        expect(cloud.events, isEmpty);
      },
    );

    test('external-family suspension remains origin scoped', () async {
      final bridge = PlatformRuntimeBridge();
      final responses = <GatewayResponse>[];
      bridge
        ..registerSessionOrigin(
          'telegram-session',
          OriginContext(
            platformFamily: PlatformFamily('telegram'),
            transport: PlatformTransport('bot'),
            platformId: 'telegram-main',
            routeId: 'chat-42',
            sessionId: 'telegram-session',
          ),
        )
        ..attachResponseSink(responses.add);

      unawaited(
        bridge.requestToolPermission(
          sessionId: 'telegram-session',
          payload: const {
            'request_id': 'permission-external',
            'tool_name': 'shell_execute',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(responses, hasLength(1));
      expect(responses.single.platformId, 'telegram-main');
      expect(responses.single.delivery.scope, DeliveryScope.origin);
      expect(responses.single.delivery.routeId, 'chat-42');
    });
  });
}

class _RecordingChannel implements PlatformSessionChannel {
  final List<Map<String, dynamic>> events = [];

  @override
  Future<void> sendProtocolEvent(
    String eventType,
    Map<String, dynamic> payload,
  ) async {
    events.add({'event': eventType, 'payload': payload});
  }
}
