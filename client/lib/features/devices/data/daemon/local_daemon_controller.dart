import 'package:sanad_client/core/config/app_config.dart';

abstract class LocalDaemonController {
  static const int defaultPort = 58085;
  static const String defaultHost = '127.0.0.1';
  static const Duration restartSafetyTimeout = Duration(minutes: 1);
  static const Duration restartRequestTimeout = Duration(seconds: 65);
  static String get defaultUrl => AppConfig.localGatewayUrl;

  /// Check if the local daemon is currently running and responsive.
  Future<bool> isDaemonRunning();

  /// Retrieve the current health status of the daemon.
  Future<Map<String, dynamic>?> getDaemonHealth();

  /// Get the running daemon version.
  Future<String?> getDaemonVersion();

  /// Start the local daemon process or service.
  Future<bool> startDaemon();

  /// Stop the local daemon process or service.
  Future<bool> stopDaemon();

  /// Restart the local daemon process or service.
  Future<bool> restartDaemon();

  /// Update the local daemon (by pulling source or downloading the compiled binary).
  Future<bool> updateDaemon({
    String? tag,
    void Function(double progress)? onProgress,
  });

  /// Check if the background service configuration is installed on the host.
  bool isServiceInstalled();

  /// Whether the daemon should be automatically started on app startup.
  bool get shouldAutoStart;

  /// Install/Register the daemon background service configuration on the host.
  Future<bool> install();
}
