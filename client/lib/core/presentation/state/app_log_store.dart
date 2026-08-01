import 'dart:convert';
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:sanad_client/core/utils/logger.dart';

class AppLogStore {
  List<String> get logs => clientLogs;
  ValueNotifier<List<String>> get logNotifier => clientLogNotifier;

  AppLogStore() {
    developer.registerExtension('ext.sanad.getLogs', (method, parameters) async {
      return developer.ServiceExtensionResponse.result(
        json.encode({
          'logs': logs,
        }),
      );
    });
  }

  void dispose() {
    // Shared global notifier, do not dispose here
  }
}
