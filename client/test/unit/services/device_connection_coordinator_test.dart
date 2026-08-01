import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/fake_socket.dart';

void main() {
  test('prefers local when sanadagent agent is on the same device and local socket is ready', () {
    final cloudSocket = FakeSanadSocketService(hardwareId: 'device-1')..setConnected(true);
    final localSocket = FakeSanadSocketService(hardwareId: 'device-1')..setConnected(true);
    final coordinator = DeviceConnectionCoordinator(
      cloudSocketService: cloudSocket,
      localSocketService: localSocket,
      currentDeviceId: 'device-1',
    );

    final agent = DeviceConfig(id: 'agent-1', name: 'SanadAgent', hardwareId: 'device-1', isOnline: true);

    final endpoint = coordinator.resolve(agent);

    expect(endpoint.scope, ConnectionScope.local);
    expect(identical(endpoint.socketService, localSocket), isTrue);
    expect(endpoint.isLocalReachable, isTrue);

    coordinator.dispose();
    cloudSocket.dispose();
    localSocket.dispose();
  });

  test('falls back to cloud when local socket is unavailable', () {
    final cloudSocket = FakeSanadSocketService(hardwareId: 'device-1')..setConnected(true);
    final localSocket = FakeSanadSocketService(hardwareId: 'device-1');
    final coordinator = DeviceConnectionCoordinator(
      cloudSocketService: cloudSocket,
      localSocketService: localSocket,
      currentDeviceId: 'device-1',
    );

    final agent = DeviceConfig(id: 'agent-1', name: 'SanadAgent', hardwareId: 'device-1', isOnline: true);

    final endpoint = coordinator.resolve(agent);

    expect(endpoint.scope, ConnectionScope.cloud);
    expect(identical(endpoint.socketService, cloudSocket), isTrue);
    expect(endpoint.isLocalReachable, isFalse);

    coordinator.dispose();
    cloudSocket.dispose();
    localSocket.dispose();
  });

  test('does not invent a new agent type while decorating local metadata', () {
    final socket = FakeSanadSocketService(hardwareId: 'device-1')..setConnected(true);
    final coordinator = DeviceConnectionCoordinator(
      cloudSocketService: socket,
      localSocketService: socket,
      currentDeviceId: 'device-1',
    );

    final agent = DeviceConfig(id: 'agent-1', name: 'SanadAgent', hardwareId: 'device-1', isOnline: true);

    final decorated = coordinator.decorateAgent(agent);

    expect(decorated.isLocalReachable, isTrue);
    expect(decorated.prefersLocalConnection, isTrue);

    coordinator.dispose();
    socket.dispose();
  });

  test('respects custom expectedVersion parameter', () {
    final cloudSocket = FakeSanadSocketService(hardwareId: 'device-1');
    final localSocket = FakeSanadSocketService(hardwareId: 'device-1');
    final coordinator = DeviceConnectionCoordinator(
      cloudSocketService: cloudSocket,
      localSocketService: localSocket,
      currentDeviceId: 'device-1',
      expectedVersion: '2.0.0',
    );

    expect(coordinator.expectedVersion, '2.0.0');

    coordinator.dispose();
    cloudSocket.dispose();
    localSocket.dispose();
  });
}
