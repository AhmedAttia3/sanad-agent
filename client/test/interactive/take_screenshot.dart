import 'package:flutter_driver/flutter_driver.dart';
import 'dart:io';

/// take_screenshot.dart — Agent Visual Verification Tool
///
/// Connects to the running sanad-client app via FlutterDriver and saves
/// a PNG screenshot of the current screen to verify layout visually.
///
/// Prerequisites:
///   - App running with --print-dtd and driver extensions:
///     fvm flutter run -d macos --print-dtd -t lib/driver_main.dart
///   - VM_SERVICE_URL environment variable must be set.
///
/// Usage:
///   VM_SERVICE_URL="http://127.0.0.1:PORT/TOKEN/" fvm dart test/interactive/take_screenshot.dart
///
/// This saves a screenshot inside `test/interactive/screenshots/` folder.

void main() async {
  final serviceUrl = Platform.environment['VM_SERVICE_URL'];
  if (serviceUrl == null || serviceUrl.isEmpty) {
    print('Error: VM_SERVICE_URL environment variable is not set.');
    print('Usage: VM_SERVICE_URL="http://127.0.0.1:PORT/TOKEN/" fvm dart test/interactive/take_screenshot.dart');
    exit(1);
  }

  print('Connecting to Flutter Driver...');
  final driver = await FlutterDriver.connect();
  print('Connected successfully!');

  try {
    print('Taking screenshot...');
    final pixels = await driver.screenshot();

    final dir = Directory('test/interactive/screenshots');
    if (!dir.existsSync()) {
      dir.createSync(recursive: true);
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final file = File('${dir.path}/screenshot_$timestamp.png');
    await file.writeAsBytes(pixels);

    print('-----------------------------------------');
    print('✅ Screenshot successfully saved to:');
    print('   ${file.absolute.path}');
    print('-----------------------------------------');
  } catch (e) {
    print('Error capturing screenshot: $e');
  } finally {
    print('Closing driver...');
    await driver.close();
    print('Driver closed.');
  }
}
