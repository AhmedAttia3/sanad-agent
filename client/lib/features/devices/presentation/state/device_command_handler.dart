import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';

class DeviceCommandHandler {
  DeviceCommandHandler({
    dynamic localToolRuntime,
    dynamic sanadSocketController,
  });

  Future<void> handle(Map<String, dynamic> data) async {
    // No-op: Platform tool execution moved to the daemon
  }

  void updateSocketController(SanadSocketService newController) {
    // No-op: Platform tool execution moved to the daemon
  }
}
