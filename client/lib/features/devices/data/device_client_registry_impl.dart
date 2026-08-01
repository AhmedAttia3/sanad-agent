import 'package:sanad_client/infrastructure/devices/models/device_client.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/devices/domain/device_client_registry.dart';
import 'package:sanad_client/infrastructure/devices/transport/universal_device_client.dart';

import 'device_connection_coordinator.dart';

class DeviceClientRegistryImpl implements IDeviceClientRegistry {
  final DeviceConnectionCoordinator _connectionCoordinator;
  final Map<String, DeviceClient> _clientsByAgentId = {};
  final Map<String, ConnectionScope> _scopeByAgentId = {};

  DeviceClientRegistryImpl(this._connectionCoordinator);

  @override
  DeviceClient getOrCreateClientForAgent(DeviceConfig config) {
    final endpoint = _connectionCoordinator.resolve(config);
    final existing = _clientsByAgentId[config.id];
    final existingScope = _scopeByAgentId[config.id];
    if (existing != null && existingScope == endpoint.scope) return existing;

    if (existing is UniversalDeviceClient) {
      existing.updateSocketService(endpoint.socketService);
      _scopeByAgentId[config.id] = endpoint.scope;
      return existing;
    }

    existing?.dispose();

    final client = UniversalDeviceClient(
      config,
      endpoint.socketService,
    );
    _clientsByAgentId[config.id] = client;
    _scopeByAgentId[config.id] = endpoint.scope;
    return client;
  }

  @override
  void retainClientsFor(List<DeviceConfig> agents) {
    final liveAgentIds = agents.map((agent) => agent.id).toSet();
    final staleAgentIds = _clientsByAgentId.keys.where((id) => !liveAgentIds.contains(id)).toList();

    for (final id in staleAgentIds) {
      _clientsByAgentId.remove(id)?.dispose();
      _scopeByAgentId.remove(id);
    }
  }

  @override
  void clear() {
    for (final client in _clientsByAgentId.values) {
      client.dispose();
    }
    _clientsByAgentId.clear();
    _scopeByAgentId.clear();
  }

  @override
  void dispose() {
    clear();
  }
}
