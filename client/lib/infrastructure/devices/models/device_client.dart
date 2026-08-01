import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

/// Low-level protocol adapter for agent-specific command/event traffic.
abstract class DeviceClient {
  /// Get the agent configuration
  DeviceConfig get config;

  /// Get the socket controller
  SanadSocketService get controller;

  /// Stream of events from the agent
  Stream<Map<String, dynamic>> get events;

  /// Whether the underlying socket transport is connected.
  bool get isConnected;

  /// Sends a fire-and-forget command to the active agent protocol.
  void sendCommand({
    required String command,
    Map<String, dynamic>? payload,
  });

  /// Sends a request that expects a correlated response event.
  Future<Map<String, dynamic>?> request({
    required String command,
    required Map<String, dynamic> payload,
    required String requestId,
    Duration timeout = const Duration(seconds: 10),
  });

  /// Clean up resources
  void dispose();
}
