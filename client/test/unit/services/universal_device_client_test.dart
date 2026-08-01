import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/infrastructure/devices/transport/universal_device_client.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../mocks/mock_socket_service.dart';

const _deviceId = 'device-uuid';
const _hardwareId = 'test-device-id';

DeviceConfig _makeConfig() => DeviceConfig(id: _deviceId, name: 'Test Device', hardwareId: _hardwareId, isOnline: true);

void main() {
  late FakeSanadSocketService service;
  late UniversalDeviceClient client;

  setUp(() {
    service = FakeSanadSocketService(hardwareId: _hardwareId);
    service.setConnected(true);
    client = UniversalDeviceClient(_makeConfig(), service);
  });

  tearDown(() {
    client.dispose();
    service.dispose();
  });

  test('exposes filtered protocol events for the active agent', () async {
    final events = <Map<String, dynamic>>[];
    final sub = client.events.listen(events.add);

    service.eventRouter.routeEvent({
      'device_id': _deviceId,
      'type': 'event',
      'event': 'ack',
      'payload': {'status': 'started'},
    });
    service.eventRouter.routeEvent({
      'device_id': 'other-device',
      'type': 'event',
      'event': 'ack',
      'payload': {'status': 'ignored'},
    });

    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single['device_id'], _deviceId);
    await sub.cancel();
  });

  test('sendCommand delegates to socket command gateway', () async {
    client.sendCommand(command: 'think', payload: {'message': 'hello'});

    expect(service.capturedCommands, hasLength(1));
    expect(service.capturedCommands.single['command'], 'think');
    expect(service.capturedCommands.single['device_id'], _deviceId);
  });

  test('request resolves when a matching response event arrives', () async {
    final future = client.request(command: 'get_sessions', payload: {'request_id': 'req-1'}, requestId: 'req-1');

    service.eventRouter.routeEvent({
      'device_id': _deviceId,
      'type': 'event',
      'event': 'sessions_list',
      'request_id': 'req-1',
      'payload': {
        'request_id': 'req-1',
        'sessions': [],
      },
    });

    final response = await future;
    expect(response?['event'], 'sessions_list');
  });
}
