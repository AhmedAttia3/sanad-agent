import 'dart:io';
import 'package:sanad_agent/core/setup/service_manager.dart';

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    _printUsage();
    return;
  }

  final command = args.first.toLowerCase();
  switch (command) {
    case 'install':
      print('Installing Sanad Agent background service...');
      final ok = await ServiceManager.install();
      if (ok) {
        print('✓ Service installed and registered successfully!');
      } else {
        print(
          '❌ Failed to install service. Please ensure you have sufficient permissions.',
        );
        exit(1);
      }
      break;

    case 'uninstall':
      print('Uninstalling Sanad Agent background service...');
      final ok = await ServiceManager.uninstall();
      if (ok) {
        print('✓ Service uninstalled successfully!');
      } else {
        print('❌ Failed to uninstall service.');
        exit(1);
      }
      break;

    case 'start':
      print('Starting Sanad Agent background service...');
      final ok = await ServiceManager.start();
      if (ok) {
        print('✓ Service started successfully.');
      } else {
        print('❌ Failed to start service.');
        exit(1);
      }
      break;

    case 'stop':
      print('Stopping Sanad Agent background service...');
      final ok = await ServiceManager.stop();
      if (ok) {
        print('✓ Service stopped successfully.');
      } else {
        print('❌ Failed to stop service.');
        exit(1);
      }
      break;

    case 'restart':
      print('Restarting Sanad Agent background service...');
      final ok = await ServiceManager.restart();
      if (ok) {
        print('✓ Service restarted successfully.');
      } else {
        print('❌ Failed to restart service.');
        exit(1);
      }
      break;

    case 'status':
      final status = await ServiceManager.getStatus();
      final installed = ServiceManager.isServiceInstalled();
      print('Sanad Agent Service Status:');
      print('  Installed: ${installed ? "Yes" : "No"}');
      print('  State:     $status');
      break;

    default:
      print('Unknown service command: "$command"\n');
      _printUsage();
      exit(1);
  }
}

void _printUsage() {
  print('Usage: sanad service <action>\n');
  print('Actions:');
  print(
    '  install      Register and start the agent daemon as a background system service',
  );
  print('  uninstall    Stop and unregister the background system service');
  print('  start        Start the registered system service');
  print('  stop         Stop the running system service');
  print('  restart      Restart the running system service');
  print('  status       Check if the service is installed and running');
}
