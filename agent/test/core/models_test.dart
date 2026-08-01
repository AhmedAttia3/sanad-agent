import 'package:test/test.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/core/models/tool_call.dart';
import 'package:sanad_agent/core/models/agent_response.dart';
import 'package:sanad_agent/core/models/llm_provider_state.dart';

void main() {
  group('Models Serialization', () {
    test('ToolCall serialization', () {
      final toolCall = ToolCall(
        id: '1',
        name: 'test_tool',
        arguments: {'arg': 1},
        providerState: const LLMProviderState(
          namespace: 'codex_responses',
          data: {'response_item_id': 'fc_1'},
        ),
      );
      final json = toolCall.toJson();
      expect(json['id'], '1');
      expect(json['name'], 'test_tool');
      expect(json['arguments']['arg'], 1);
      expect(json['providerState']['data']['response_item_id'], 'fc_1');

      final fromJson = ToolCall.fromJson(json);
      expect(fromJson.id, '1');
      expect(fromJson.name, 'test_tool');
      expect(fromJson.arguments['arg'], 1);
      expect(fromJson.providerState?.data['response_item_id'], 'fc_1');
    });

    test('Message serialization', () {
      final message = Message(
        role: MessageRole.assistant,
        content: 'Hello',
        reasoning: 'I should say hello',
        providerState: const LLMProviderState(
          namespace: 'codex_responses',
          issuer: 'openai-codex:https://example.test',
          data: {
            'reasoning_items': [
              {'encrypted_content': 'opaque'},
            ],
          },
        ),
        finishReason: LLMFinishReason.incomplete,
      );
      final json = message.toJson();
      expect(json['role'], 'assistant');
      expect(json['content'], 'Hello');
      expect(json['reasoning'], 'I should say hello');
      expect(json['providerState']['namespace'], 'codex_responses');
      expect(json['finishReason'], 'incomplete');

      final fromJson = Message.fromJson(json);
      expect(fromJson.role, MessageRole.assistant);
      expect(fromJson.content, 'Hello');
      expect(fromJson.reasoning, 'I should say hello');
      expect(
        fromJson.providerState?.issuer,
        'openai-codex:https://example.test',
      );
      expect(fromJson.providerState?.data['reasoning_items'], hasLength(1));
      expect(fromJson.finishReason, LLMFinishReason.incomplete);
    });

    test(
      'Message accepts legacy/future finish reasons and can clear state',
      () {
        final message = Message(
          role: MessageRole.assistant,
          providerState: const LLMProviderState(
            namespace: 'codex_responses',
            data: {'encrypted_content': 'opaque'},
          ),
        );
        final legacyJson = message.toJson()..remove('finishReason');
        final futureJson = message.toJson()
          ..['finishReason'] = 'future_terminal_state';

        expect(
          Message.fromJson(legacyJson).finishReason,
          LLMFinishReason.unknown,
        );
        expect(
          Message.fromJson(futureJson).finishReason,
          LLMFinishReason.unknown,
        );
        expect(message.copyWith().providerState, isNotNull);
        expect(
          message.copyWith(clearProviderState: true).providerState,
          isNull,
        );
      },
    );

    test('AgentResponse serialization', () {
      final message = Message(role: MessageRole.user, content: 'Hi');
      final response = AgentResponse(
        message: message,
        isToolCall: false,
        finishReason: LLMFinishReason.incomplete,
      );
      final json = response.toJson();
      expect(json['isToolCall'], false);
      expect(json['finishReason'], 'incomplete');

      final fromJson = AgentResponse.fromJson(json);
      expect(fromJson.message.role, MessageRole.user);
      expect(fromJson.isToolCall, false);
      expect(fromJson.finishReason, LLMFinishReason.incomplete);
    });

    test('AgentResponse accepts legacy and future finish reasons', () {
      final message = Message(role: MessageRole.assistant, content: 'Hi');
      final legacyJson = AgentResponse(message: message).toJson()
        ..remove('finishReason');
      final futureJson = AgentResponse(message: message).toJson()
        ..['finishReason'] = 'future_terminal_state';

      expect(
        AgentResponse.fromJson(legacyJson).finishReason,
        LLMFinishReason.unknown,
      );
      expect(
        AgentResponse.fromJson(futureJson).finishReason,
        LLMFinishReason.unknown,
      );
    });
  });
}
