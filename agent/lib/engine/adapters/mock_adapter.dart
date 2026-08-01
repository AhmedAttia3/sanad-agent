import '../../core/models/message.dart';
import '../../core/models/tool_call.dart';
import '../../core/models/agent_response.dart';
import '../../capabilities/models/tool_schema.dart';
import 'llm_adapter.dart';
import 'llm_request_options.dart';
import '../../interfaces/platforms/sanad_gateway/capabilities.dart';

class MockLLMAdapter implements LLMAdapter {
  String get availableModelsSource => 'live';

  @override
  Future<int> getContextLimit([String? modelOverride]) async => 4000;

  @override
  Future<List<ModelOption>> getAvailableModels() async {
    return [
      ModelOption(
        value: 'mock/gpt-3.5-turbo',
        label: 'Mock GPT-3.5 Turbo',
        provider: 'mock',
        contextWindow: 4000,
      ),
    ];
  }

  @override
  Future<AgentResponse> generateResponse(
    List<Message> history, {
    List<ToolSchema>? tools,
    String? modelOverride,
    LLMRequestOptions options = const LLMRequestOptions(),
  }) async {
    final lastMessage = history.last;

    // If the last message was a tool result, return a final conclusion
    if (lastMessage.role == MessageRole.tool) {
      return AgentResponse(
        message: Message(
          role: MessageRole.assistant,
          content:
              'I have processed the tool output. Result: ${lastMessage.content}. Task complete.',
        ),
        usage: {
          'prompt_tokens': 5,
          'completion_tokens': 10,
          'total_tokens': 15,
        },
        model: 'gpt-3.5-turbo',
        provider: 'mock',
      );
    }

    // Find the actual user request (skipping internal tool loops)
    final lastUserMessageContent =
        history.lastWhere((m) => m.role == MessageRole.user).content ?? '';

    if (lastUserMessageContent.contains('Delegate')) {
      return AgentResponse(
        message: Message(
          role: MessageRole.assistant,
          content: 'I will delegate this task to a sub-agent.',
          toolCalls: [
            ToolCall(
              id: 'call_del_123',
              name: 'delegate_task',
              arguments: {
                'task': 'Check the system time',
                'role': 'System Admin',
              },
            ),
          ],
        ),
        isToolCall: true,
        usage: {
          'prompt_tokens': 12,
          'completion_tokens': 15,
          'total_tokens': 27,
        },
        model: 'gpt-3.5-turbo',
        provider: 'mock',
      );
    }

    if (lastUserMessageContent.contains('Schedule')) {
      return AgentResponse(
        message: Message(
          role: MessageRole.assistant,
          content: 'I am scheduling a task for you.',
          toolCalls: [
            ToolCall(
              id: 'call_sched_123',
              name: 'schedule_task',
              arguments: {
                'task': 'Reminder: Hello from the future!',
                'time': 'in 5 seconds',
              },
            ),
          ],
        ),
        isToolCall: true,
        usage: {
          'prompt_tokens': 15,
          'completion_tokens': 18,
          'total_tokens': 33,
        },
        model: 'gpt-3.5-turbo',
        provider: 'mock',
      );
    }

    String responseContent =
        'I am a mock AI. You said: $lastUserMessageContent';

    if (lastUserMessageContent.contains('What is my name')) {
      responseContent =
          'I remember you! Your name and preferences should be in my system context.';
    }

    return AgentResponse(
      message: Message(role: MessageRole.assistant, content: responseContent),
      usage: {'prompt_tokens': 10, 'completion_tokens': 20, 'total_tokens': 30},
      model: 'gpt-3.5-turbo',
      provider: 'mock',
    );
  }

  @override
  Stream<AgentResponse> generateStream(
    List<Message> history, {
    List<ToolSchema>? tools,
    String? modelOverride,
    LLMRequestOptions options = const LLMRequestOptions(),
  }) async* {
    final response = await generateResponse(
      history,
      tools: tools,
      modelOverride: modelOverride,
      options: options,
    );
    final content = response.message.content ?? '';

    if (content.isEmpty && response.isToolCall) {
      yield AgentResponse(
        message: response.message,
        isToolCall: true,
        usage: response.usage,
        model: response.model,
        provider: response.provider,
      );
      return;
    }

    for (var i = 0; i < content.length; i++) {
      final isLast = i == content.length - 1;
      yield AgentResponse(
        message: Message(
          role: MessageRole.assistant,
          content: content[i],
          toolCalls: isLast ? response.message.toolCalls : null,
        ),
        isToolCall: isLast ? response.isToolCall : false,
        usage: isLast ? response.usage : null,
        model: isLast ? response.model : null,
        provider: isLast ? response.provider : null,
      );
      await Future.delayed(Duration(milliseconds: 10));
    }
  }
}
