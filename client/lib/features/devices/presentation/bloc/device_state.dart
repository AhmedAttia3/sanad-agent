import 'package:equatable/equatable.dart';
import '../../domain/models/device_config.dart';

abstract class DeviceState extends Equatable {
  const DeviceState();

  @override
  List<Object?> get props => [];
}

class AgentInitial extends DeviceState {}

class DeviceLoading extends DeviceState {}

class DeviceActive extends DeviceState {
  final DeviceConfig activeAgent;
  final List<DeviceConfig> agents;

  const DeviceActive({
    required this.activeAgent,
    this.agents = const [],
  });

  @override
  List<Object?> get props => [activeAgent, agents];

  DeviceActive copyWith({
    DeviceConfig? activeAgent,
    List<DeviceConfig>? agents,
  }) {
    return DeviceActive(
      activeAgent: activeAgent ?? this.activeAgent,
      agents: agents ?? this.agents,
    );
  }
}

class DeviceNoActive extends DeviceState {
  final List<DeviceConfig> agents;
  final bool isLoadingFromBackend;

  const DeviceNoActive({
    this.agents = const [],
    this.isLoadingFromBackend = false,
  });

  @override
  List<Object?> get props => [agents, isLoadingFromBackend];

  DeviceNoActive copyWith({
    List<DeviceConfig>? agents,
    bool? isLoadingFromBackend,
  }) {
    return DeviceNoActive(
      agents: agents ?? this.agents,
      isLoadingFromBackend: isLoadingFromBackend ?? this.isLoadingFromBackend,
    );
  }
}

class AgentError extends DeviceState {
  final String message;
  const AgentError(this.message);

  @override
  List<Object?> get props => [message];
}
