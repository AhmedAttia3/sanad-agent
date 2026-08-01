import 'dart:io';
import 'automation_service_interface.dart';
import 'macos_automation_service.dart';
import 'windows_automation_service.dart';
import 'linux_automation_service.dart';

class AutomationServiceFactory {
  static AutomationServiceInterface? _instance;

  static AutomationServiceInterface get instance {
    if (_instance != null) {
      return _instance!;
    }

    if (Platform.isMacOS) {
      _instance = MacosAutomationService();
    } else if (Platform.isWindows) {
      _instance = WindowsAutomationService();
    } else if (Platform.isLinux) {
      _instance = LinuxAutomationService();
    } else {
      throw UnsupportedError(
        'Unsupported operating system: ${Platform.operatingSystem}',
      );
    }

    return _instance!;
  }
}
