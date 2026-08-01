import 'dart:async';

import 'package:get_it/get_it.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/interfaces/gateway_manager.dart';
import 'package:sanad_agent/interfaces/models/delivery/models.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';
import 'package:sanad_agent/interfaces/platforms/base_platform.dart';
import 'package:sanad_agent/interfaces/runtime/session_run_orchestrator.dart';
import 'package:test/test.dart';

void main() {
  tearDown(() async {
    await GetIt.I.reset();
  });

  test(
    'one command failure is contained and later commands are still handled',
    () async {
      final orchestrator = _ThrowingOrchestrator();
      GetIt.I.registerSingleton<SessionRunOrchestrator>(orchestrator);
      final platform = _RecordingPlatform();
      final gateway = GatewayManager()..registerPlatform(platform);
      addTearDown(gateway.stop);
      await gateway.start();

      platform.add(_event('session-failure-1'));
      platform.add(_event('session-failure-2'));
      await Future<void>.delayed(const Duration(milliseconds: 40));

      expect(
        orchestrator.handledSessions,
        equals(['session-failure-1', 'session-failure-2']),
      );
      expect(platform.responses, hasLength(2));
      expect(
        platform.responses.map((response) => response.message.content),
        everyElement('Error: The command could not be processed.'),
      );
    },
  );
}

GatewayEvent _event(String sessionId) {
  return GatewayEvent(
    sessionId: sessionId,
    platformId: 'recording-platform',
    message: Message(role: MessageRole.user, content: 'run'),
  );
}

class _ThrowingOrchestrator extends SessionRunOrchestrator {
  final List<String> handledSessions = [];

  @override
  Future<void> handleEvent(GatewayEvent event) async {
    handledSessions.add(event.sessionId);
    throw StateError('command failure');
  }
}

class _RecordingPlatform extends BasePlatform {
  final StreamController<GatewayEvent> _events =
      StreamController<GatewayEvent>();
  final List<GatewayResponse> responses = [];

  void add(GatewayEvent event) => _events.add(event);

  @override
  PlatformDescriptor get descriptor => const PlatformDescriptor.sanadClient(
    transport: PlatformTransport.local,
    platformInstanceId: 'recording-platform',
  );

  @override
  Stream<GatewayEvent> get eventStream => _events.stream;

  @override
  String get platformId => 'recording-platform';

  @override
  Future<void> initialize() async {}

  @override
  Future<void> sendResponse(GatewayResponse response) async {
    responses.add(response);
  }

  @override
  Future<void> dispose() => _events.close();
}
