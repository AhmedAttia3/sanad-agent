import 'dart:io';

class AppConfig {
  /// Returns `true` if the agent is running from the source code via the Dart VM
  /// (e.g. `fvm dart run`), and `false` if it is running as a compiled native binary.
  static bool get isSourceRun {
    final execPath = Platform.resolvedExecutable;
    return execPath.contains('dart-sdk') ||
        execPath.endsWith('dart') ||
        execPath.endsWith('dart.exe');
  }
}
