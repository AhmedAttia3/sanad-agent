import 'package:logging/logging.dart';
import 'session_manager.dart';
import '../core/di.dart';

class Curator {
  final _logger = Logger('Curator');
  final SessionManager _sessionManager;

  Curator({SessionManager? sessionManager})
    : _sessionManager = sessionManager ?? getIt<SessionManager>();

  Future<void> collectStats() async {
    _logger.info('Curator: Collecting session statistics...');
    final sessions = _sessionManager.getAllSessions();

    int totalMessages = 0;
    Map<String, int> modelUsage = {};

    for (var session in sessions) {
      final messages = _sessionManager.getMessages(session.sessionId);
      totalMessages += messages.length;

      final model = session.model;
      modelUsage[model] = (modelUsage[model] ?? 0) + 1;
    }

    _logger.info('--- Curator Report ---');
    _logger.info('Total Sessions: ${sessions.length}');
    _logger.info('Total Messages: $totalMessages');
    _logger.info('Model Distribution: $modelUsage');
    _logger.info('----------------------');
  }

  Future<void> runEvolutionLoop() async {
    // This would run every 24 hours in a real scenario
    _logger.info('Curator: Running evolution loop...');
    await collectStats();

    // Logic for self-improvement could go here
    // e.g., analyzing frequent tasks and proposing new tools
  }
}
