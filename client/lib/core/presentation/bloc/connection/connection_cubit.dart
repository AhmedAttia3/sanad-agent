import 'dart:async';

import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'connection_state.dart';

class ConnectionCubit extends Cubit<ConnectionState> {
  final SanadSocketService socketService;
  StreamSubscription? _socketSubscription;

  ConnectionCubit({
    required this.socketService,
  }) : super(const ConnectionState()) {
    _socketSubscription = socketService.lifecycleStateStream.listen((_) => _updateSocketStatus());
    _updateSocketStatus();
  }

  void _updateSocketStatus() {
    final status = switch (socketService.lifecycleState) {
      SocketLifecycleState.disconnected => ConnectionStatus.disconnected,
      SocketLifecycleState.connecting || SocketLifecycleState.authenticating => ConnectionStatus.connecting,
      SocketLifecycleState.ready => ConnectionStatus.connected,
      SocketLifecycleState.authFailed => ConnectionStatus.error,
      SocketLifecycleState.error => ConnectionStatus.error,
    };
    if (state.socketStatus != status) {
      emit(state.copyWith(socketStatus: status));
    }
  }

  @override
  Future<void> close() async {
    await _socketSubscription?.cancel();
    return super.close();
  }
}
