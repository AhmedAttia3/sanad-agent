import 'package:sanad_client/features/devices/data/device_command_client.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';

class DeviceSkillEntry {
  const DeviceSkillEntry({
    required this.name,
    required this.origin,
    required this.active,
    this.description,
    this.shadowedBy,
  });

  final String name;
  final String origin;
  final bool active;
  final String? description;
  final String? shadowedBy;

  factory DeviceSkillEntry.fromJson(Map<String, dynamic> json) {
    final origin = Map<String, dynamic>.from(json['origin'] as Map? ?? const {});
    final shadowed = Map<String, dynamic>.from(json['shadowed_by'] as Map? ?? const {});
    return DeviceSkillEntry(
      name: json['name']?.toString() ?? 'Unnamed skill',
      description: json['description']?.toString(),
      origin: origin['kind']?.toString() ?? origin['scope']?.toString() ?? 'device',
      active: json['active'] != false,
      shadowedBy: shadowed['name']?.toString(),
    );
  }
}

class DeviceSkillsClient {
  DeviceSkillsClient(this._commands);

  final DeviceCommandClient _commands;

  Future<List<DeviceSkillEntry>> list(DeviceConfig device, {String? workspaceId}) async {
    final payload = await _commands.request(
      device: device,
      command: 'list_skills',
      expectedEvent: 'skills_list',
      payload: {
        if (workspaceId != null) 'workspace_id': workspaceId,
        'include_shadowed': workspaceId != null,
      },
    );
    return (payload['skills'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => DeviceSkillEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
  }
}
