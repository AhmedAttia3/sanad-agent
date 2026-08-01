import 'dart:io';
import 'package:logging/logging.dart';
import 'package:sanad_agent/core/config.dart';

/// Global list containing the last 1000 formatted log entries of the daemon in memory.
final List<String> agentLogs = [];

/// Global list of connected log WebSocket clients.
final List<WebSocket> agentLogWebSockets = [];

/// Initializes the customized, beautiful, and colored logger for the local daemon.
void initLogger(Config config) {
  // Parse log level from configuration
  final configuredLevel = config.logLevel;
  Logger.root.level = _parseLevel(configuredLevel);

  final colorEnabled = config.logColor;
  final maxLength = config.logMaxLength;

  Logger.root.onRecord.listen((record) {
    final timeStr = _formatTime(record.time);
    final levelName = record.level.name;
    final loggerName = record.loggerName;

    // Default formatting tokens
    String levelToken = '[$levelName]';
    String sourceToken = '[$loggerName]';
    String messageText = record.message;
    String resetColor = '';

    if (colorEnabled) {
      resetColor = '\x1B[0m';

      // 1. Colorize Log Level
      if (record.level >= Level.SEVERE) {
        levelToken = '\x1B[31m[$levelName]\x1B[0m'; // Red
      } else if (record.level >= Level.WARNING) {
        levelToken = '\x1B[33m[$levelName]\x1B[0m'; // Yellow
      } else if (record.level >= Level.INFO) {
        levelToken = '\x1B[32m[$levelName]\x1B[0m'; // Green
      } else if (record.level >= Level.CONFIG) {
        levelToken = '\x1B[34m[$levelName]\x1B[0m'; // Blue
      } else {
        levelToken = '\x1B[90m[$levelName]\x1B[0m'; // Gray for FINE/DEBUG
      }

      // 2. Colorize Logger/Source Name (Cyan)
      sourceToken = '\x1B[36m[$loggerName]\x1B[0m';

      // 3. Smart parsing of incoming/outgoing indicators for beautiful colors
      if (messageText.contains('[Agent]')) {
        if (messageText.contains('Thinking')) {
          messageText =
              '\x1B[1;35m$messageText\x1B[0m'; // Bold Magenta for Thinking
        } else if (messageText.contains('Requesting tool call')) {
          messageText =
              '\x1B[1;36m$messageText\x1B[0m'; // Bold Cyan for requesting tool calls
        } else if (messageText.contains('executed successfully')) {
          messageText =
              '\x1B[1;32m$messageText\x1B[0m'; // Bold Green for successful tool execution
        } else if (messageText.contains('Final Answer')) {
          messageText =
              '\x1B[1;33m$messageText\x1B[0m'; // Bold Yellow for final answer
        } else {
          messageText =
              '\x1B[1;34m$messageText\x1B[0m'; // Bold Blue for other agent states
        }
      } else if (messageText.contains('⬇️') ||
          messageText.toLowerCase().contains('received')) {
        // Magenta for incoming events
        messageText = '\x1B[35m$messageText\x1B[0m';
      } else if (messageText.contains('⬆️') ||
          messageText.toLowerCase().contains('emitting') ||
          messageText.toLowerCase().contains('sending')) {
        // Green for outgoing events
        messageText = '\x1B[32m$messageText\x1B[0m';
      } else if (messageText.toLowerCase().contains('connected')) {
        // Bold light-green/blue for connection
        messageText = '\x1B[1;32m$messageText\x1B[0m';
      } else if (messageText.toLowerCase().contains('disconnected') ||
          messageText.toLowerCase().contains('failed')) {
        // Bold yellow/red for disconnection or failures
        messageText = '\x1B[1;33m$messageText\x1B[0m';
      }
    }

    // 4. Truncate very long messages/payloads to keep terminal clean
    if (messageText.length > maxLength) {
      messageText =
          '${messageText.substring(0, maxLength)}... $resetColor[truncated, original len: ${record.message.length}]';
    }

    // 5. Build and print the structured log line
    final logOutput = '$timeStr $levelToken $sourceToken: $messageText';
    print(logOutput);
    agentLogs.add(logOutput);

    // 6. Handle errors and stack traces beautifully if they are present
    if (record.error != null) {
      final errStr = colorEnabled
          ? '\x1B[1;31mError Details:\x1B[0m \x1B[31m${record.error}\x1B[0m'
          : 'Error Details: ${record.error}';
      print(errStr);
      agentLogs.add(errStr);
    }
    if (record.stackTrace != null) {
      final stStr = colorEnabled
          ? '\x1B[90m${record.stackTrace}\x1B[0m'
          : record.stackTrace.toString();
      print(stStr);
      agentLogs.add(stStr);
    }

    // Keep memory capped at 1000 items
    while (agentLogs.length > 1000) {
      agentLogs.removeAt(0);
    }

    // Broadcast to active log WebSockets
    for (final ws in List<WebSocket>.from(agentLogWebSockets)) {
      try {
        ws.add(logOutput);
      } catch (_) {
        agentLogWebSockets.remove(ws);
      }
    }
  });
}

/// Helper to parse a String into a logging Level.
Level _parseLevel(String levelName) {
  switch (levelName.toUpperCase()) {
    case 'ALL':
      return Level.ALL;
    case 'FINEST':
      return Level.FINEST;
    case 'FINER':
      return Level.FINER;
    case 'FINE':
    case 'DEBUG':
      return Level.FINE;
    case 'CONFIG':
      return Level.CONFIG;
    case 'INFO':
      return Level.INFO;
    case 'WARNING':
      return Level.WARNING;
    case 'SEVERE':
      return Level.SEVERE;
    case 'SHOUT':
      return Level.SHOUT;
    case 'OFF':
      return Level.OFF;
    default:
      return Level.INFO;
  }
}

/// Custom timestamp formatter: HH:mm:ss.SSS
String _formatTime(DateTime time) {
  final hour = time.hour.toString().padLeft(2, '0');
  final minute = time.minute.toString().padLeft(2, '0');
  final second = time.second.toString().padLeft(2, '0');
  final millisecond = time.millisecond.toString().padLeft(3, '0');
  return '$hour:$minute:$second.$millisecond';
}
