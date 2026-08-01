import 'package:equatable/equatable.dart';

enum ConnectionStatus { disconnected, connecting, connected, reconnecting, error }

class ConnectionState extends Equatable {
  final ConnectionStatus socketStatus;
  final String? error;

  const ConnectionState({
    this.socketStatus = ConnectionStatus.disconnected,
    this.error,
  });

  ConnectionState copyWith({
    ConnectionStatus? socketStatus,
    String? error,
  }) {
    return ConnectionState(
      socketStatus: socketStatus ?? this.socketStatus,
      error: error,
    );
  }

  @override
  List<Object?> get props => [socketStatus, error];
}
