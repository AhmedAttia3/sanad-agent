import 'package:sanad_client/features/devices/data/device_command_client.dart';
import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/mcp/domain/models/mcp_runtime_models.dart';
import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';

class McpRuntimeClient {
  McpRuntimeClient({
    DeviceCommandClient? commandClient,
    DeviceConnectionCoordinator? connectionCoordinator,
    DeviceConfig? Function()? defaultDevice,
  }) : assert(commandClient != null || connectionCoordinator != null),
       _commandClient = commandClient ?? DeviceCommandClient(connectionCoordinator: connectionCoordinator!),
       _defaultDevice = defaultDevice ?? (() => null);

  final DeviceCommandClient _commandClient;
  final DeviceConfig? Function() _defaultDevice;

  Future<McpRuntimeSnapshot> listServers({
    DeviceConfig? device,
    String? workspaceId,
  }) async {
    final payload = await _request(
      device: _resolveDevice(device),
      command: 'list_mcp_servers',
      payload: {
        if (workspaceId != null && workspaceId.trim().isNotEmpty) 'workspace_id': workspaceId.trim(),
      },
      expectedEvent: 'mcp_servers_list',
    );
    return McpRuntimeSnapshot.fromJson(payload);
  }

  Future<McpRuntimeSnapshot> saveServer({
    DeviceConfig? device,
    required McpConfigScope scope,
    required McpServerConfig config,
    String? workspaceId,
  }) async {
    final payload = await _request(
      device: _resolveDevice(device),
      command: 'save_mcp_server',
      payload: {
        'scope': scope.wireValue,
        'config': {
          'name': config.name,
          ...config.toConfigJson(),
        },
        if (workspaceId != null && workspaceId.trim().isNotEmpty) 'workspace_id': workspaceId.trim(),
      },
      expectedEvent: 'mcp_server_saved',
    );
    return McpRuntimeSnapshot.fromJson(payload);
  }

  Future<McpRuntimeSnapshot> deleteServer({
    DeviceConfig? device,
    required McpConfigScope scope,
    required String serverName,
    String? workspaceId,
  }) async {
    final payload = await _request(
      device: _resolveDevice(device),
      command: 'delete_mcp_server',
      payload: {
        'scope': scope.wireValue,
        'server_name': serverName,
        if (workspaceId != null && workspaceId.trim().isNotEmpty) 'workspace_id': workspaceId.trim(),
      },
      expectedEvent: 'mcp_server_deleted',
    );
    return McpRuntimeSnapshot.fromJson(payload);
  }

  Future<McpRuntimeSnapshot> replaceConfig({
    DeviceConfig? device,
    required McpConfigScope scope,
    required Map<String, dynamic> document,
    String? workspaceId,
  }) async {
    final payload = await _request(
      device: _resolveDevice(device),
      command: 'replace_mcp_config',
      payload: {
        'scope': scope.wireValue,
        'document': document,
        if (workspaceId != null && workspaceId.trim().isNotEmpty) 'workspace_id': workspaceId.trim(),
      },
      expectedEvent: 'mcp_config_replaced',
    );
    return McpRuntimeSnapshot.fromJson(payload);
  }

  Future<McpServerInspection> inspectServer({
    DeviceConfig? device,
    required String serverName,
    McpConfigScope scope = McpConfigScope.effective,
    String? workspaceId,
  }) async {
    final payload = await _request(
      device: _resolveDevice(device),
      command: 'inspect_mcp_server',
      payload: {
        'scope': scope.wireValue,
        'server_name': serverName,
        if (workspaceId != null && workspaceId.trim().isNotEmpty) 'workspace_id': workspaceId.trim(),
      },
      expectedEvent: 'mcp_server_inspected',
    );
    return McpServerInspection.fromJson(payload);
  }

  Future<Map<String, dynamic>> _request({
    required DeviceConfig device,
    required String command,
    required Map<String, dynamic> payload,
    required String expectedEvent,
    Duration timeout = const Duration(seconds: 10),
  }) async {
    return _commandClient.request(
      device: device,
      command: command,
      payload: payload,
      expectedEvent: expectedEvent,
      timeout: timeout,
    );
  }

  DeviceConfig _resolveDevice(DeviceConfig? device) {
    final resolved = device ?? _defaultDevice();
    if (resolved == null) {
      throw StateError('Select a device before managing MCP servers.');
    }
    return resolved;
  }
}
