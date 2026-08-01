export '../mocks/mock_socket_service.dart';

import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';

import '../mocks/mock_socket_service.dart';

DeviceConnectionCoordinator createTestResolver({
  FakeSanadSocketService? cloudSocket,
  FakeSanadSocketService? localSocket,
  String currentDeviceId = 'test-device-id',
}) {
  return DeviceConnectionCoordinator(
    cloudSocketService: cloudSocket ?? FakeSanadSocketService(hardwareId: currentDeviceId),
    localSocketService: localSocket ?? FakeSanadSocketService(hardwareId: currentDeviceId),
    currentDeviceId: currentDeviceId,
  );
}
