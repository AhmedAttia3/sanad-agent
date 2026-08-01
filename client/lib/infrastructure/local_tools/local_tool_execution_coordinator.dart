import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';

class LocalToolExecutionCoordinator {
  LocalToolExecutionCoordinator({
    dynamic agentCommandHandler,
    dynamic sanadSocketController,
    dynamic localToolRuntime,
  });

  void updateSocketController(SanadSocketService newController) {
    // No-op: Platform tool execution moved to the daemon
  }

  void dispose() {
    // No-op: Platform tool execution moved to the daemon
  }
}
