import 'dart:async';
import 'package:sanad_agent/interfaces/models/delivery/models.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';
import 'package:sanad_agent/interfaces/platforms/base_platform.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/evolution/session_manager.dart';
import 'package:logging/logging.dart';

class CronScheduler extends BasePlatform {
  final _logger = Logger('CronScheduler');

  @override
  String get platformId => 'cron';

  @override
  PlatformDescriptor get descriptor => const PlatformDescriptor(
    platformFamily: PlatformFamily.cli,
    transport: PlatformTransport.cli,
    platformInstanceId: 'cron',
  );

  final StreamController<GatewayEvent> _controller =
      StreamController<GatewayEvent>.broadcast();

  @override
  Stream<GatewayEvent> get eventStream => _controller.stream;

  final List<ScheduledTaskMetadata> _tasks = [];
  final _sessionManager = SessionManager();

  List<ScheduledTaskMetadata> get activeTasks => List.unmodifiable(_tasks);

  void scheduleTask(
    DateTime time,
    String task, {
    String? sessionId,
    String? id,
  }) {
    final taskId = id ?? 'task_${DateTime.now().millisecondsSinceEpoch}';
    final targetSessionId = sessionId ?? 'cron-session';

    // Persist to DB
    _sessionManager.db.saveScheduledTask(taskId, task, time, targetSessionId);

    _scheduleInMemory(time, task, targetSessionId, taskId);
  }

  void _scheduleInMemory(
    DateTime time,
    String task,
    String sessionId,
    String id,
  ) {
    final now = DateTime.now();
    final delay = time.difference(now);

    _logger.info('Scheduling task: "$task" at $time (delay: $delay, id: $id)');

    if (delay.isNegative) {
      _logger.warning('Task $id scheduled in the past. Executing immediately.');
      _emitEvent(task, sessionId);
      _sessionManager.db.deleteScheduledTask(id);
      return;
    }

    final timer = Timer(delay, () {
      _logger.info('Executing scheduled task: "$task" (id: $id)');
      _tasks.removeWhere((t) => t.id == id);
      _sessionManager.db.deleteScheduledTask(id);
      _emitEvent(task, sessionId);
    });

    _tasks.add(
      ScheduledTaskMetadata(
        id: id,
        time: time,
        task: task,
        sessionId: sessionId,
        timer: timer,
      ),
    );
  }

  void _emitEvent(String task, String sessionId) {
    _controller.add(
      GatewayEvent(
        sessionId: sessionId,
        platformId: platformId,
        type: 'cron',
        runId: 'cron_${DateTime.now().millisecondsSinceEpoch}',
        message: Message(role: MessageRole.user, content: task),
      ),
    );
  }

  @override
  Future<void> sendResponse(GatewayResponse response) async {
    _logger.info(
      'Received response for cron task: ${response.message.content}',
    );
  }

  @override
  Future<void> initialize() async {
    _logger.info('CronScheduler initializing from DB...');
    final dbTasks = _sessionManager.db.getAllScheduledTasks();

    for (var taskData in dbTasks) {
      final runAt = DateTime.parse(taskData['run_at']);
      final id = taskData['id'];
      final task = taskData['task'];
      final sessionId = taskData['session_id'];

      // Grace period of 5 minutes for missed tasks during downtime
      if (runAt.isAfter(DateTime.now().subtract(const Duration(minutes: 5)))) {
        _scheduleInMemory(runAt, task, sessionId, id);
      } else {
        _logger.warning('Skipping stale task: "$task" scheduled for $runAt');
        _sessionManager.db.deleteScheduledTask(id);
      }
    }
    _logger.info(
      'CronScheduler initialized with ${_tasks.length} active tasks.',
    );
  }

  @override
  Future<void> dispose() async {
    for (var t in _tasks) {
      t.timer.cancel();
    }
    _tasks.clear();
    await _controller.close();
    _logger.info('CronScheduler disposed.');
  }
}

class ScheduledTaskMetadata {
  final String id;
  final DateTime time;
  final String task;
  final String sessionId;
  final Timer timer;

  ScheduledTaskMetadata({
    required this.id,
    required this.time,
    required this.task,
    required this.sessionId,
    required this.timer,
  });
}
