import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/core/models/agent_response.dart';
import 'package:sanad_agent/engine/context_engine.dart';
import 'package:sanad_agent/engine/adapters/llm_adapter.dart';

import 'context_engine_test.mocks.dart';

@GenerateMocks([LLMAdapter])
void main() {
  late MockLLMAdapter mockAdapter;
  late ContextEngine contextEngine;

  setUp(() {
    mockAdapter = MockLLMAdapter();
    contextEngine = ContextEngine(maxTokens: 50, adapter: mockAdapter);

    // Default stub for getContextLimit
    when(mockAdapter.getContextLimit(any)).thenAnswer((_) async => 4096);
  });

  group('ContextEngine', () {
    test('estimateTokens calculates approximate token count', () {
      final history = [
        Message(role: MessageRole.user, content: 'Hello world'),
        Message(
          role: MessageRole.assistant,
          content: 'Hi there, how can I help?',
        ),
      ];

      final tokens = contextEngine.estimateTokens(history);
      expect(tokens, greaterThan(0));
    });

    test('compressIfNeeded does nothing if under limit', () async {
      final history = [Message(role: MessageRole.user, content: 'Short')];

      final result = await contextEngine.compressIfNeeded(history);
      expect(result, equals(history));
      verifyNever(mockAdapter.generateResponse(any));
    });

    test('compressIfNeeded summarizes when over limit', () async {
      when(mockAdapter.getContextLimit(any)).thenAnswer((_) async => 50);

      final history = List.generate(
        20,
        (i) => Message(
          role: i % 2 == 0 ? MessageRole.user : MessageRole.assistant,
          content: 'Long message content $i to exceed limit',
        ),
      );

      when(mockAdapter.generateResponse(any)).thenAnswer(
        (_) async => AgentResponse(
          message: Message(
            role: MessageRole.assistant,
            content: 'This is a summary.',
          ),
        ),
      );

      final result = await contextEngine.compressIfNeeded(history);

      expect(result.length, lessThan(history.length));
      expect(
        result.any(
          (m) => m.content?.contains('Previous conversation summary') ?? false,
        ),
        isTrue,
      );
    });
  });
}
