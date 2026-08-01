import 'package:sanad_client/utils/app_platform.dart';

class DesktopOnlyGuard {
  static bool get canExecuteTools => AppPlatform.isDesktop;

  static void assertDesktop(String feature) {
    if (!canExecuteTools) throw UnsupportedError('$feature: desktop only');
  }
}
