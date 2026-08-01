import 'package:sanad_agent/core/models/agent_response.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/engine/metrics_tracker.dart';
import 'package:test/test.dart';

void main() {
  AgentResponse response(Map<String, dynamic> usage) => AgentResponse(
    message: Message(role: MessageRole.assistant),
    usage: usage,
  );

  test('lastUsage contains only the latest provider-reported values', () {
    final tracker = MetricsTracker();

    tracker.updateMetrics(
      response({
        'prompt_tokens': 100,
        'completion_tokens': 20,
        'total_tokens': 120,
        'prompt_tokens_details': {'cached_tokens': 80},
      }),
    );
    tracker.updateMetrics(response({'prompt_tokens': 140}));

    expect(tracker.lastUsage['input_tokens'], 140);
    expect(tracker.lastUsage, isNot(contains('output_tokens')));
    expect(tracker.lastUsage, isNot(contains('total_tokens')));
    expect(tracker.lastUsage, isNot(contains('cached_tokens')));
  });

  test('a provider-less invocation cannot reuse older usage', () {
    final tracker = MetricsTracker();
    tracker.updateMetrics(response({'input_tokens': 100, 'cached_tokens': 80}));

    tracker.beginInvocation();

    expect(tracker.lastUsage, isEmpty);
  });

  test('normalizes cached tokens without changing their value', () {
    final tracker = MetricsTracker();

    tracker.updateMetrics(
      response({
        'input_tokens': 194000,
        'input_tokens_details': {'cached_tokens': 120000},
      }),
    );

    expect(tracker.lastUsage['input_tokens'], 194000);
    expect(tracker.lastUsage['cached_tokens'], 120000);
    expect(tracker.lastUsage, isNot(contains('total_tokens')));
  });
}
