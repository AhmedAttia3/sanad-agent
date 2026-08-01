import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/data/mappers/unified_device_mapper.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_state.dart';

void main() {
  group('Reasoning event mapping', () {
    test('reasoning_stream maps to EventKind.reasoning', () {
      final event = UnifiedDeviceMapper().mapLiveEvent({
        'event': 'reasoning_stream',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'content': 'Analyzing the problem...',
        },
      });

      expect(event, isNotNull);
      expect(event!.kind, EventKind.reasoning);
      expect(event.status, EventStatus.running);
      expect(event.text, 'Analyzing the problem...');
    });

    test('reasoning (finalized) maps to EventKind.reasoning with done status', () {
      final event = UnifiedDeviceMapper().mapLiveEvent({
        'event': 'reasoning',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'content': 'I should consider edge cases.',
        },
      });

      expect(event, isNotNull);
      expect(event!.kind, EventKind.reasoning);
      expect(event.status, EventStatus.done);
    });

    test('thought_stream still maps to EventKind.thinking', () {
      final event = UnifiedDeviceMapper().mapLiveEvent({
        'event': 'thought_stream',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'content': 'Some intermediate text...',
        },
      });

      expect(event, isNotNull);
      expect(event!.kind, EventKind.thinking);
    });

    test('reasoning and thoughts in one model step keep distinct ids', () {
      final mapper = UnifiedDeviceMapper();
      final reasoning = mapper.mapLiveEvent({
        'event': 'reasoning_stream',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'model_step_id': 'step-1',
          'content': 'Reasoning',
        },
      });
      final thought = mapper.mapLiveEvent({
        'event': 'thought_stream',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'model_step_id': 'step-1',
          'content': 'Answer draft',
        },
      });

      expect(reasoning?.id, isNot(thought?.id));
    });

    test('empty stream events do not create timeline bubbles', () {
      final mapper = UnifiedDeviceMapper();

      expect(
        mapper.mapLiveEvent({
          'event': 'reasoning_stream',
          'payload': {'session_id': 's1', 'content': '   '},
        }),
        isNull,
      );
      expect(
        mapper.mapLiveEvent({
          'event': 'thought_stream',
          'payload': {'session_id': 's1', 'content': ''},
        }),
        isNull,
      );
    });

    test('a successor thinking event removes the running reasoning row', () {
      final state = ConversationState();
      final timestamp = DateTime.utc(2026, 7, 25);
      state.apply(
        CanonicalEvent(
          id: 'reasoning-step-1',
          kind: EventKind.reasoning,
          status: EventStatus.running,
          text: 'Reasoning',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      );
      state.apply(
        CanonicalEvent(
          id: 'thinking-step-1',
          kind: EventKind.thinking,
          status: EventStatus.running,
          text: 'Answer draft',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      );

      expect(
        state.events.any((event) => event.kind == EventKind.reasoning),
        isFalse,
        reason: 'reasoning is transient and removed as soon as a successor arrives',
      );
      expect(
        state.events.any((event) => event.kind == EventKind.thinking),
        isTrue,
      );
    });

    test('final answer removes running reasoning and answer draft', () {
      final state = ConversationState();
      final timestamp = DateTime.utc(2026, 7, 25);
      state.apply(
        CanonicalEvent(
          id: 'reasoning-step-1',
          kind: EventKind.reasoning,
          status: EventStatus.running,
          text: 'Reasoning',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      );
      state.apply(
        CanonicalEvent(
          id: 'thinking-step-1',
          kind: EventKind.thinking,
          status: EventStatus.running,
          text: 'Answer draft',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      );
      state.apply(
        CanonicalEvent(
          id: 'final-step-1',
          kind: EventKind.finalAnswer,
          status: EventStatus.done,
          text: 'Final answer',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      );

      expect(
        state.events.any((event) => event.kind == EventKind.reasoning),
        isFalse,
        reason: 'reasoning is transient and never finalized into the timeline',
      );
      expect(
        state.events.any((event) => event.kind == EventKind.thinking),
        isFalse,
      );
      expect(
        state.events.any((event) => event.kind == EventKind.finalAnswer),
        isTrue,
      );
    });

    test('setHistory never rebuilds reasoning rows', () {
      final state = ConversationState();
      final timestamp = DateTime.utc(2026, 7, 25);
      state.setHistory([
        CanonicalEvent(
          id: 'user-1',
          kind: EventKind.userMessage,
          status: EventStatus.done,
          text: 'question',
          timestamp: timestamp,
          runId: 'r1',
        ),
        CanonicalEvent(
          id: 'reasoning-step-1',
          kind: EventKind.reasoning,
          status: EventStatus.done,
          text: 'Reasoning',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
        CanonicalEvent(
          id: 'final-step-1',
          kind: EventKind.finalAnswer,
          status: EventStatus.done,
          text: 'Final answer',
          timestamp: timestamp,
          runId: 'r1',
          modelStepId: 'step-1',
        ),
      ]);

      expect(
        state.events.any((event) => event.kind == EventKind.reasoning),
        isFalse,
        reason: 'reasoning must not be rebuilt when loading from history',
      );
      expect(state.events.any((event) => event.kind == EventKind.userMessage), isTrue);
      expect(state.events.any((event) => event.kind == EventKind.finalAnswer), isTrue);
    });

    test('final_answer maps to EventKind.finalAnswer not reasoning', () {
      final event = UnifiedDeviceMapper().mapLiveEvent({
        'event': 'final_answer',
        'payload': {
          'session_id': 's1',
          'run_id': 'r1',
          'content': 'The answer is 42.',
        },
      });

      expect(event, isNotNull);
      expect(event!.kind, EventKind.finalAnswer);
    });
  });
}
