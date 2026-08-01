import 'package:sanad_agent/capabilities/models/tool_schema.dart';
import 'package:sanad_agent/capabilities/tools/base_tool.dart';
import 'package:sanad_agent/engine/agent_runner.dart';
import 'package:sanad_agent/core/di.dart';

class DelegateTaskTool extends BaseTool {
  @override
  ToolSchema get schema => ToolSchema(
    name: 'delegate_task',
    description:
        'Delegate a specific task to a sub-agent. Useful for parallel work or specialized roles.',
    parameters: {
      'type': 'object',
      'properties': {
        'task': {
          'type': 'string',
          'description': 'The detailed task description for the sub-agent.',
        },
        'role': {
          'type': 'string',
          'description':
              'The role or persona the sub-agent should adopt (e.g., "Reviewer", "Programmer").',
        },
      },
      'required': ['task'],
    },
  );

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    final taskVal = args['task'];
    final roleVal = args['role'];

    if (taskVal == null || taskVal is! String || taskVal.trim().isEmpty) {
      return 'Error: "task" parameter is required and must be a non-empty string.';
    }
    if (roleVal != null && roleVal is! String) {
      return 'Error: "role" parameter, if provided, must be a string.';
    }

    final task = taskVal;
    final role = roleVal as String?;

    // Create a new AgentRunner with a fresh session
    // Using null for existingSessionId creates a new session in AgentRunner constructor
    final subAgent = getIt<AgentRunner>(param1: null);

    if (role != null) {
      subAgent.addSystemMessage(
        'You are a specialized sub-agent with the role: $role. Complete the assigned task efficiently.',
      );
    } else {
      subAgent.addSystemMessage(
        'You are a helpful sub-agent. Complete the assigned task efficiently.',
      );
    }

    try {
      final response = await subAgent.sendMessage(task);
      return 'Sub-agent result:\n${response.content ?? "No content returned."}';
    } catch (e) {
      return 'Error during sub-agent execution: $e';
    }
  }
}
