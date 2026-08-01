import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';
import 'package:sanad_client/features/conversations/presentation/widgets/user_message_tile.dart';

void main() {
  testWidgets('short user message does not show Read more', (tester) async {
    final event = CanonicalEvent(
      id: 'msg-1',
      kind: EventKind.userMessage,
      text: 'Short message',
      timestamp: DateTime.utc(2026, 7, 23),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: UserMessageTile(event: event),
        ),
      ),
    );

    expect(find.text('Read more'), findsNothing);
    expect(find.text('See less'), findsNothing);
  });

  testWidgets('long user message with > 5 lines shows Read more and toggles to See less when tapped', (tester) async {
    final longText = List.generate(10, (index) => 'Line ${index + 1}').join('\n');
    final event = CanonicalEvent(
      id: 'msg-2',
      kind: EventKind.userMessage,
      text: longText,
      timestamp: DateTime.utc(2026, 7, 23),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: UserMessageTile(event: event),
          ),
        ),
      ),
    );

    expect(find.text('Read more'), findsOneWidget);
    expect(find.text('See less'), findsNothing);

    // Tap anywhere on the message tile
    await tester.tap(find.text('Read more'));
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsNothing);
    expect(find.text('See less'), findsOneWidget);

    // Tap again to collapse
    await tester.tap(find.text('See less'));
    await tester.pumpAndSettle();

    expect(find.text('Read more'), findsOneWidget);
    expect(find.text('See less'), findsNothing);
  });
}
