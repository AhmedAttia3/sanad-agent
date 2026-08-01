import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final command = Platform.isWindows
      ? ['cmd', '/c', 'fvm flutter test test/e2e/local_dual_connection_e2e_test.dart']
      : ['/bin/zsh', '-lc', 'fvm flutter test test/e2e/local_dual_connection_e2e_test.dart'];

  stdout.writeln('🚀 Running real local dual-connection E2E test...');
  stdout.writeln(' - cwd: ${Directory.current.path}');
  stdout.writeln(' - command: ${jsonEncode(command)}');

  final result = await Process.start(
    command.first,
    command.sublist(1),
    workingDirectory: Directory.current.path,
    environment: Platform.environment,
    mode: ProcessStartMode.inheritStdio,
  );

  final exitCode = await result.exitCode;
  if (exitCode != 0) {
    stderr.writeln('❌ Real local dual-connection E2E failed with exit code $exitCode');
    exit(exitCode);
  }

  stdout.writeln('✅ Real local dual-connection E2E passed.');
}
