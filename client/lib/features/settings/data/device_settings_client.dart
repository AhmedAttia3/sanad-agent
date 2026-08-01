import 'package:sanad_client/features/devices/data/device_command_client.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

class ManagedToggleSetting {
  const ManagedToggleSetting({required this.enabled, required this.managedExternally});

  final bool enabled;
  final bool managedExternally;

  factory ManagedToggleSetting.fromJson(Map<String, dynamic> json) => ManagedToggleSetting(
    enabled: json['enabled'] == true,
    managedExternally: json['managed_externally'] == true,
  );
}

class DeviceSettingsSnapshot {
  const DeviceSettingsSnapshot({
    required this.cloudConnection,
    required this.computerUse,
    required this.computerUsePermissionsGranted,
    required this.webSearchProvider,
    required this.serperConfigured,
    required this.webSearchProviderManagedExternally,
    required this.serperKeyManagedExternally,
    required this.providerAutoFailover,
    this.restartRequired = false,
  });

  final ManagedToggleSetting cloudConnection;
  final ManagedToggleSetting computerUse;
  final bool computerUsePermissionsGranted;
  final String webSearchProvider;
  final bool serperConfigured;
  final bool webSearchProviderManagedExternally;
  final bool serperKeyManagedExternally;
  final ManagedToggleSetting providerAutoFailover;
  final bool restartRequired;

  factory DeviceSettingsSnapshot.fromJson(Map<String, dynamic> json) {
    final webSearch = Map<String, dynamic>.from(json['web_search'] as Map? ?? const {});
    return DeviceSettingsSnapshot(
      cloudConnection: ManagedToggleSetting.fromJson(
        Map<String, dynamic>.from(json['cloud_connection'] as Map? ?? const {}),
      ),
      computerUse: ManagedToggleSetting.fromJson(
        Map<String, dynamic>.from(json['computer_use'] as Map? ?? const {}),
      ),
      computerUsePermissionsGranted: json['computer_use_permissions_granted'] == true,
      webSearchProvider: webSearch['provider']?.toString().trim().toLowerCase() ?? 'ddg',
      serperConfigured: webSearch['serper_configured'] == true,
      webSearchProviderManagedExternally: webSearch['provider_managed_externally'] == true,
      serperKeyManagedExternally: webSearch['serper_key_managed_externally'] == true,
      providerAutoFailover: ManagedToggleSetting.fromJson(
        Map<String, dynamic>.from(json['provider_auto_failover'] as Map? ?? const {}),
      ),
      restartRequired: json['restart_required'] == true,
    );
  }
}

class DeviceSettingsClient {
  DeviceSettingsClient(this._commands);

  final DeviceCommandClient _commands;

  Future<DeviceSettingsSnapshot> load(DeviceConfig device) async {
    final payload = await _commands.request(
      device: device,
      command: 'device.settings.get',
      expectedEvent: 'device.settings.snapshot',
    );
    return DeviceSettingsSnapshot.fromJson(payload);
  }

  Future<DeviceSettingsSnapshot> update(DeviceConfig device, Map<String, dynamic> changes) async {
    final payload = await _commands.request(
      device: device,
      command: 'device.settings.update',
      expectedEvent: 'device.settings.updated',
      payload: {'changes': changes},
    );
    return DeviceSettingsSnapshot.fromJson(payload);
  }

  Future<bool> requestComputerUsePermissions(DeviceConfig device) async {
    final payload = await _commands.request(
      device: device,
      command: 'system.request_computer_use_permissions',
      expectedEvent: 'system_request_computer_use_permissions_result',
    );
    return payload['granted'] == true;
  }
}
