import 'package:flutter_driver/flutter_driver.dart';
import 'dart:io';

/// send_message_example.dart — Reference Interactive Action Script
///
/// Demonstrates how an AI agent can simulate user interactions like tapping,
/// entering text, and clicking elements using FlutterDriver keys.
///
/// Prerequisites:
///   - App running with --print-dtd and driver extensions:
///     fvm flutter run -d macos --print-dtd -t lib/driver_main.dart
///   - Target screen (e.g. Chat Session) must already be open and active.
///   - VM_SERVICE_URL environment variable must be set.
///
/// ⚠️ CRITICAL RULE: Never terminate this script midway. If aborted while a tap
/// is in progress, the app's driver service is locked in a "guarded" state,
/// causing future runs to crash with "Guarded function conflict".
/// Recovery: Trigger a hot_restart in the app to clear the guarded state.
///
/// Usage:
///   VM_SERVICE_URL="http://127.0.0.1:PORT/TOKEN/" fvm dart test/interactive/send_message_example.dart

void main() async {
  final serviceUrl = Platform.environment['VM_SERVICE_URL'];
  if (serviceUrl == null || serviceUrl.isEmpty) {
    print('Error: VM_SERVICE_URL environment variable is not set.');
    exit(1);
  }

  print('Connecting to Flutter Driver...');
  final driver = await FlutterDriver.connect();
  print('Connected successfully!');

  try {
    print('Tapping chat input field...');
    await driver.tap(find.byValueKey('chat_input'));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final testMessage = 'Hello from automated agent test!';
    print('Entering text: "$testMessage"');
    await driver.enterText(testMessage);
    await Future<void>.delayed(const Duration(milliseconds: 500));

    print('Tapping send button...');
    await driver.tap(find.byValueKey('send_message_btn'));
    print('Send tapped successfully!');

    // Wait for the agent to finish thinking and reply
    print('Waiting 10 seconds for response...');
    await Future<void>.delayed(const Duration(seconds: 10));

    print('Test complete! Run inspect_ui.dart or take_screenshot.dart to verify results.');
  } catch (e) {
    print('Error during interaction simulation: $e');
  } finally {
    print('Closing driver connection...');
    await driver.close();
    print('Driver closed.');
  }
}
