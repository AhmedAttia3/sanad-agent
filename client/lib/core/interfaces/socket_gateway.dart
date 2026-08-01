abstract class ISocketGateway {
  void sendDeviceCommand({
    required String deviceId,
    required String command,
    Map<String, dynamic>? payload,
  });

  void sendToolResult({
    required String runId,
    String? output,
    String? error,
    bool isError = false,
    String? deviceId,
  });
}
