import 'package:sanad_agent/capabilities/models/tool_schema.dart';
import 'package:sanad_agent/capabilities/tools/base_tool.dart';
import 'package:sanad_agent/evolution/cron_scheduler.dart';
import 'package:sanad_agent/core/di.dart';

class ListScheduledTasksTool extends BaseTool {
  @override
  ToolSchema get schema => ToolSchema(
    name: 'list_scheduled_tasks',
    description: 'List all currently scheduled tasks.',
    parameters: {'type': 'object', 'properties': {}},
  );

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    final scheduler = getIt<CronScheduler>();
    final tasks = scheduler.activeTasks;

    if (tasks.isEmpty) {
      return 'No tasks are currently scheduled.';
    }

    final buffer = StringBuffer('Scheduled Tasks:\n');
    for (var i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      buffer.writeln(
        '${i + 1}. Task: "${t.task}" at ${t.time} (Session: ${t.sessionId})',
      );
    }

    return buffer.toString();
  }
}
