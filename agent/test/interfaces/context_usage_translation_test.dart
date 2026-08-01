import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/interfaces/models/gateway_event.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/translators/agent_to_canonical.dart';
import 'package:test/test.dart';

void main() {
  test('tool use carries the latest context usage snapshot', () {
    final event = AgentToCanonical.translate(
      GatewayResponse(
        sessionId: 'session-1',
        message: Message(role: MessageRole.tool, content: '{}'),
        isComplete: false,
        isToolUse: true,
        toolName: 'search',
        contextUsage: const {
          'input_tokens': 194000,
          'cached_tokens': 120000,
          'context_window_tokens': 258000,
        },
      ),
    );

    expect(event.type, 'tool_use');
    expect(event.payload['context_usage'], {
      'input_tokens': 194000,
      'cached_tokens': 120000,
      'context_window_tokens': 258000,
    });
  });
}
