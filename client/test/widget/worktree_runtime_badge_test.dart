import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/home/presentation/widgets/status_bar.dart';

void main() {
  testWidgets('shows a readable worktree label and full branch tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.bottomLeft,
            child: WorktreeRuntimeBadge(
              worktreeName: 'sanad-dev-worktree-runtime',
              branch: 'codex/sanad-dev-worktree-runtime',
              foregroundColor: Colors.black,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const Key('worktree_runtime_badge')), findsOneWidget);
    expect(find.text('sanad-dev-worktree-runtime'), findsOneWidget);

    final tooltip = tester.widget<Tooltip>(find.byType(Tooltip));
    expect(
      tooltip.message,
      'Isolated worktree: sanad-dev-worktree-runtime\n'
      'Branch: codex/sanad-dev-worktree-runtime',
    );
  });

  testWidgets('keeps long worktree names within the available width', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 120,
          child: WorktreeRuntimeBadge(
            worktreeName: 'a-very-long-worktree-name-that-must-not-overflow',
            branch: 'codex/long-worktree',
            foregroundColor: Colors.black,
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    final label = tester.widget<Text>(
      find.text('a-very-long-worktree-name-that-must-not-overflow'),
    );
    expect(label.overflow, TextOverflow.ellipsis);
  });
}
