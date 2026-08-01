import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_state.dart';

void main() {
  test('accepted replay removes only the targeted latest turn projection', () {
    final state = ConversationState();
    state.setHistory([
      CanonicalEvent(
        id: 'user-1',
        kind: EventKind.userMessage,
        text: 'first',
        timestamp: DateTime.utc(2026, 7, 18),
        metadata: const {'request_id': 'request-1'},
      ),
      CanonicalEvent(
        id: 'answer-1',
        kind: EventKind.finalAnswer,
        text: 'first answer',
        timestamp: DateTime.utc(2026, 7, 18),
      ),
      CanonicalEvent(
        id: 'user-2',
        kind: EventKind.userMessage,
        text: 'second',
        timestamp: DateTime.utc(2026, 7, 18),
        metadata: const {'request_id': 'request-2'},
      ),
      CanonicalEvent(
        id: 'answer-2',
        kind: EventKind.finalAnswer,
        text: 'second answer',
        timestamp: DateTime.utc(2026, 7, 18),
      ),
    ]);

    expect(state.truncateAtUserRequest('request-2'), isTrue);
    expect(state.events.map((event) => event.id), ['user-1', 'answer-1']);
  });
}
