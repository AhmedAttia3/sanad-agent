import 'package:sanad_client/infrastructure/devices/models/device_client.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

abstract class IDeviceClientRegistry {
  DeviceClient getOrCreateClientForAgent(DeviceConfig config);

  void retainClientsFor(List<DeviceConfig> agents);
  void clear();
  void dispose();
}
