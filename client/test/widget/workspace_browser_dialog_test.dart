import 'dart:async';

import 'package:sanad_client/features/conversations/domain/models/workspace_tree_entry.dart';
import 'package:sanad_client/features/conversations/domain/models/workspace_tree_snapshot.dart';
import 'package:sanad_client/features/conversations/presentation/widgets/workspace_browser_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('navigates folders and returns the selected path', (tester) async {
    final requests = <String?>[];

    Future<WorkspaceTreeSnapshot> loader({String? path}) async {
      requests.add(path);
      if (path == '/repo/apps') {
        return const WorkspaceTreeSnapshot(
          workspaceId: '/repo',
          rootPath: '/repo',
          path: '/repo/apps',
          parentPath: '/repo',
          entries: [
            WorkspaceTreeEntry(
              name: 'sanad-client',
              path: '/repo/apps/sanad-client',
              relativePath: 'apps/sanad-client',
              isDirectory: true,
            ),
          ],
          truncated: false,
        );
      }

      return const WorkspaceTreeSnapshot(
        workspaceId: '/repo',
        rootPath: '/repo',
        path: '/repo',
        parentPath: null,
        entries: [
          WorkspaceTreeEntry(name: 'apps', path: '/repo/apps', relativePath: 'apps', isDirectory: true),
        ],
        truncated: false,
      );
    }

    String? selectedPath;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () async {
                  selectedPath = await showDialog<String>(
                    context: context,
                    builder: (_) => WorkspaceBrowserDialog(loader: loader),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    expect(requests, [null]);
    expect(find.byType(ListTile), findsOneWidget);

    await tester.tap(find.byType(ListTile));
    await tester.pump();
    await tester.pump();

    expect(requests, [null, '/repo/apps']);
    expect(find.text('sanad-client'), findsOneWidget);

    await tester.tap(find.text('Use This Folder'));
    await tester.pumpAndSettle();

    expect(selectedPath, '/repo/apps');
  });

  testWidgets('uses daemon-provided parent path to navigate back', (tester) async {
    final requests = <String?>[];

    Future<WorkspaceTreeSnapshot> loader({String? path}) async {
      requests.add(path);
      if (path == '/repo/apps') {
        return const WorkspaceTreeSnapshot(
          workspaceId: '/repo',
          rootPath: '/repo',
          path: '/repo/apps',
          parentPath: '',
          entries: [
            WorkspaceTreeEntry(
              name: 'sanad-client',
              path: '/repo/apps/sanad-client',
              relativePath: 'sanad-client',
              isDirectory: true,
            ),
          ],
          truncated: false,
        );
      }

      return const WorkspaceTreeSnapshot(
        workspaceId: '',
        rootPath: '',
        path: '',
        parentPath: null,
        entries: [
          WorkspaceTreeEntry(name: 'repo', path: '/repo/apps', relativePath: '/repo/apps', isDirectory: true),
        ],
        truncated: false,
      );
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  unawaited(
                    showDialog<String>(
                      context: context,
                      builder: (_) => WorkspaceBrowserDialog(loader: loader),
                    ),
                  );
                },
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pump();
    await tester.pump();

    await tester.tap(find.text('repo'));
    await tester.pump();
    await tester.pump();

    expect(requests, [null, '/repo/apps']);

    await tester.tap(find.text('..'));
    await tester.pump();
    await tester.pump();

    expect(requests, [null, '/repo/apps', '']);
    expect(find.text('repo'), findsOneWidget);
  });

  testWidgets('creates and renames folders then refreshes the current path', (
    tester,
  ) async {
    final loadRequests = <String?>[];
    final createRequests = <(String, String)>[];
    final renameRequests = <(String, String)>[];

    await _openBrowser(
      tester,
      loader: ({path}) async {
        loadRequests.add(path);
        return _repoSnapshot;
      },
      onCreateFolder: (parentPath, name) async {
        createRequests.add((parentPath, name));
      },
      onRenameFolder: (path, name) async {
        renameRequests.add((path, name));
      },
    );

    await tester.tap(find.byTooltip('New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'new-child');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(createRequests, [('/repo', 'new-child')]);
    expect(loadRequests, [null, '/repo']);

    await tester.tap(find.byTooltip('Rename Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'renamed-apps');
    await tester.tap(find.widgetWithText(FilledButton, 'Rename'));
    await tester.pumpAndSettle();

    expect(renameRequests, [('/repo/apps', 'renamed-apps')]);
    expect(loadRequests, [null, '/repo', '/repo']);
  });

  testWidgets('deletes only after confirmation and refreshes', (tester) async {
    final loadRequests = <String?>[];
    final deleteRequests = <String>[];

    await _openBrowser(
      tester,
      loader: ({path}) async {
        loadRequests.add(path);
        return _repoSnapshot;
      },
      onDeleteFolder: (path) async => deleteRequests.add(path),
    );

    await tester.tap(find.byTooltip('Delete Folder'));
    await tester.pumpAndSettle();
    expect(find.textContaining('cannot be undone'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel').last);
    await tester.pumpAndSettle();
    expect(deleteRequests, isEmpty);

    await tester.tap(find.byTooltip('Delete Folder'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Delete'));
    await tester.pumpAndSettle();

    expect(deleteRequests, ['/repo/apps']);
    expect(loadRequests, [null, '/repo']);
  });

  testWidgets('keeps the snapshot visible and reports mutation failures', (
    tester,
  ) async {
    await _openBrowser(
      tester,
      loader: ({path}) async => _repoSnapshot,
      onCreateFolder: (parentPath, name) async {
        throw StateError('permission denied');
      },
    );

    await tester.tap(find.byTooltip('New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), 'blocked');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('workspace-folder-mutation-error')),
      findsOneWidget,
    );
    expect(find.textContaining('permission denied'), findsOneWidget);
    expect(find.text('apps'), findsWidgets);
  });

  testWidgets('rejects multi-segment names before calling the daemon', (
    tester,
  ) async {
    var createCalls = 0;
    await _openBrowser(
      tester,
      loader: ({path}) async => _repoSnapshot,
      onCreateFolder: (parentPath, name) async => createCalls++,
    );

    await tester.tap(find.byTooltip('New Folder'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField), '../outside');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();

    expect(createCalls, 0);
    expect(find.textContaining('single path segment'), findsOneWidget);
  });

  testWidgets('does not offer mutations on an abstract system-roots snapshot', (
    tester,
  ) async {
    await _openBrowser(
      tester,
      loader: ({path}) async => const WorkspaceTreeSnapshot(
        workspaceId: '',
        rootPath: '',
        path: '',
        parentPath: null,
        entries: [
          WorkspaceTreeEntry(
            name: 'C:',
            path: r'C:\',
            relativePath: r'C:\',
            isDirectory: true,
          ),
        ],
        truncated: false,
      ),
      onCreateFolder: (parentPath, name) async {},
      onRenameFolder: (path, name) async {},
      onDeleteFolder: (path) async {},
    );

    expect(find.byTooltip('New Folder'), findsNothing);
    expect(find.byTooltip('Rename Folder'), findsNothing);
    expect(find.byTooltip('Delete Folder'), findsNothing);
  });
}

const _repoSnapshot = WorkspaceTreeSnapshot(
  workspaceId: '/repo',
  rootPath: '/repo',
  path: '/repo',
  parentPath: null,
  entries: [
    WorkspaceTreeEntry(
      name: 'apps',
      path: '/repo/apps',
      relativePath: 'apps',
      isDirectory: true,
    ),
  ],
  truncated: false,
);

Future<void> _openBrowser(
  WidgetTester tester, {
  required WorkspaceTreeLoader loader,
  WorkspaceFolderCreator? onCreateFolder,
  WorkspaceFolderRenamer? onRenameFolder,
  WorkspaceFolderDeleter? onDeleteFolder,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () {
                unawaited(
                  showDialog<String>(
                    context: context,
                    builder: (_) => WorkspaceBrowserDialog(
                      loader: loader,
                      onCreateFolder: onCreateFolder,
                      onRenameFolder: onRenameFolder,
                      onDeleteFolder: onDeleteFolder,
                    ),
                  ),
                );
              },
              child: const Text('Open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Open'));
  await tester.pumpAndSettle();
}
