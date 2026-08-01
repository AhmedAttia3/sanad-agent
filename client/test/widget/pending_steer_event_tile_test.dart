import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';
import 'package:sanad_client/features/conversations/presentation/widgets/event_tile.dart';

void main() {
  CanonicalEvent event(String state) => CanonicalEvent(
    id: 'user_raw-1',
    kind: EventKind.userMessage,
    text: 'pending message',
    timestamp: DateTime.utc(2026, 7, 15),
    metadata: {'request_id': 'raw-1', 'pending_steer_state': state},
  );

  testWidgets('pending user bubble exposes authoritative cancel action', (tester) async {
    String? cancelled;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventTile(
            event: event('pending'),
            onCancelPendingSteer: (requestId) async => cancelled = requestId,
          ),
        ),
      ),
    );

    expect(find.text('Pending'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete pending message'));
    expect(cancelled, 'raw-1');
    expect(find.text('pending message'), findsOneWidget);
  });

  testWidgets('delivered bubble keeps content without pending controls', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: EventTile(event: event('delivered'))),
      ),
    );
    expect(find.text('pending message'), findsOneWidget);
    expect(find.text('Pending'), findsNothing);
    expect(find.byTooltip('Delete pending message'), findsNothing);
  });
}
