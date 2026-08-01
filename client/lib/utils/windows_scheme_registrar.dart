import 'package:universal_io/io.dart';
import 'package:logging/logging.dart';

final _logger = Logger('WindowsSchemeRegistrar');

/// Registers the custom protocol scheme 'sanad://' in the Windows Registry under
/// HKEY_CURRENT_USER. This enables deep linking from browsers to launch the application.
Future<void> registerWindowsScheme() async {
  if (!Platform.isWindows) return;
  try {
    final exePath = Platform.resolvedExecutable;
    _logger.info('Registering Windows URL protocol scheme (sanad://)...');

    // Write registry entries to HKCU\Software\Classes\sanad
    final keys = [
      ['add', r'HKCU\Software\Classes\sanad', '/ve', '/d', 'URL:sanad Protocol', '/f'],
      ['add', r'HKCU\Software\Classes\sanad', '/v', 'URL Protocol', '/d', '', '/f'],
      ['add', r'HKCU\Software\Classes\sanad\shell\open\command', '/ve', '/d', '"$exePath" "%1"', '/f'],
    ];

    for (final args in keys) {
      final res = await Process.run('reg', args);
      if (res.exitCode != 0) {
        _logger.warning('Failed registry step: reg ${args.join(" ")}. Error: ${res.stderr}');
      }
    }
    _logger.info('Windows URL protocol scheme registered successfully.');
  } catch (e) {
    _logger.severe('Failed to register Windows URL protocol scheme: $e');
  }
}
