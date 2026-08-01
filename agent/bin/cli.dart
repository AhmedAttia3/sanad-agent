import 'dart:io';
import 'package:uuid/uuid.dart';
import 'package:sanad_agent/core/di.dart';
import 'package:sanad_agent/core/config.dart';
import 'package:sanad_agent/core/auth/auth_manager.dart';
import 'package:sanad_agent/interfaces/gateway_manager.dart';
import 'package:sanad_agent/interfaces/platforms/cli_platform.dart';

import 'setup.dart' as setup;

Future<void> main(List<String> args) async {
  print('--- Sanad Agent CLI ---');

  setupDI();
  await getIt<AuthManager>().initialize();

  final config = getIt<Config>();
  if (!config.isValid) {
    print('Error: Configuration is not valid. No LLM provider is set up yet.');
    stdout.write(
      'Would you like to run the interactive setup wizard now? [Y/n]: ',
    );
    final response = stdin.readLineSync()?.trim().toLowerCase();
    if (response == '' || response == 'y' || response == 'yes') {
      await setup.main([]);
      exit(0);
    } else {
      print(
        'Please configure a valid LLM provider in ~/.sanad/.env or run "sanad setup".',
      );
      exit(1);
    }
  }

  String? workspaceId;

  // 2. Resolve/generate unique Session ID
  String sessionId;
  if (args.isNotEmpty) {
    sessionId = args[0];
  } else {
    sessionId = const Uuid().v4();
  }

  // 3. Register and start GatewayManager with only CliPlatform
  final gatewayManager = getIt<GatewayManager>();
  gatewayManager.registerPlatform(
    CliPlatform(initialSessionId: sessionId, workspaceId: workspaceId),
  );

  await gatewayManager.start();
}
