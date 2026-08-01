import 'package:sanad_client/features/devices/domain/models/capability.dart';
import 'package:equatable/equatable.dart';

class DeviceCapabilitiesState extends Equatable {
  final Map<String, Capability> capabilitiesByAgentId;

  const DeviceCapabilitiesState({
    this.capabilitiesByAgentId = const {},
  });

  Capability getForAgent(String deviceId) {
    return capabilitiesByAgentId[deviceId] ?? const Capability();
  }

  DeviceCapabilitiesState copyWith({
    Map<String, Capability>? capabilitiesByAgentId,
  }) {
    return DeviceCapabilitiesState(
      capabilitiesByAgentId: capabilitiesByAgentId ?? this.capabilitiesByAgentId,
    );
  }

  @override
  List<Object?> get props => [capabilitiesByAgentId];
}
