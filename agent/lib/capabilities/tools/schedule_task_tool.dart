import 'package:sanad_agent/capabilities/models/tool_schema.dart';
import 'package:sanad_agent/capabilities/tools/base_tool.dart';
import 'package:sanad_agent/evolution/cron_scheduler.dart';
import 'package:sanad_agent/core/di.dart';

class ScheduleTaskTool extends BaseTool {
  @override
  ToolSchema get schema => ToolSchema(
    name: 'schedule_task',
    description:
        'Schedule a task to be executed by the agent at a specific time.',
    parameters: {
      'type': 'object',
      'properties': {
        'task': {
          'type': 'string',
          'description': 'The task description to be executed.',
        },
        'time': {
          'type': 'string',
          'description':
              'The time to execute the task (ISO8601 format or relative like "in 5 minutes").',
        },
      },
      'required': ['task', 'time'],
    },
  );

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    final taskVal = args['task'];
    final timeVal = args['time'];

    if (taskVal == null || taskVal is! String || taskVal.trim().isEmpty) {
      return 'Error: "task" parameter is required and must be a non-empty string.';
    }
    if (timeVal == null || timeVal is! String || timeVal.trim().isEmpty) {
      return 'Error: "time" parameter is required and must be a non-empty string.';
    }

    final task = taskVal;
    final timeStr = timeVal;

    DateTime? scheduledTime;

    // Simple parsing for "in X minutes" or "in X seconds"
    if (timeStr.startsWith('in ')) {
      final parts = timeStr.split(' ');
      if (parts.length >= 3) {
        final amount = int.tryParse(parts[1]);
        final unit = parts[2].toLowerCase();
        if (amount != null) {
          if (unit.contains('minute')) {
            scheduledTime = DateTime.now().add(Duration(minutes: amount));
          } else if (unit.contains('second')) {
            scheduledTime = DateTime.now().add(Duration(seconds: amount));
          } else if (unit.contains('hour')) {
            scheduledTime = DateTime.now().add(Duration(hours: amount));
          }
        }
      }
    } else {
      scheduledTime = DateTime.tryParse(timeStr);
    }

    if (scheduledTime == null) {
      return 'Error: Could not parse time "$timeStr". Please use ISO8601 format or "in X minutes".';
    }

    try {
      final scheduler = getIt<CronScheduler>();
      scheduler.scheduleTask(
        scheduledTime,
        task,
        sessionId: context?.sessionId,
      );
      return 'Task scheduled successfully for $scheduledTime';
    } catch (e) {
      return 'Error: CronScheduler not available or failed. $e';
    }
  }
}
