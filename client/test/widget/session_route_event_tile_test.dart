import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/canonical_event.dart';
import 'package:sanad_client/features/conversations/presentation/widgets/event_tile.dart';

void main() {
  testWidgets('renders auto-failover as informational timeline content', (
    tester,
  ) async {
    const text =
        'Switched automatically from NVIDIA NIM to Z.ai because NVIDIA NIM reached its rate limit. Continuing with GLM 5.2.';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EventTile(
            event: CanonicalEvent(
              id: 'route_session-1_4',
              kind: EventKind.informational,
              text: text,
              timestamp: DateTime(2026, 7, 15),
              sessionId: 'session-1',
              model: 'GLM 5.2',
              provider: 'Z.ai',
              metadata: const {
                'informational': true,
                'route_revision': 4,
              },
            ),
          ),
        ),
      ),
    );

    expect(find.text(text), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });
}
