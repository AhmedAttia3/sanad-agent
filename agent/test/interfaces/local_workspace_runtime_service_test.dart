import 'dart:io';

import 'package:sanad_agent/evolution/db/agent_state_database.dart';
import 'package:sanad_agent/evolution/db/session_db.dart';
import 'package:sanad_agent/interfaces/runtime/local_workspace_runtime_service.dart';
import 'package:test/test.dart';

void main() {
  group('LocalWorkspaceRuntimeService.browseWorkspaceTree', () {
    late Directory tempDir;
    late Directory workspaceDir;
    late LocalWorkspaceRuntimeService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'sanad-agent-workspace-runtime-test',
      );
      workspaceDir = Directory('${tempDir.path}/workspace')..createSync();
      Directory('${workspaceDir.path}/nested').createSync();
      service = LocalWorkspaceRuntimeService(
        sanadHomePath: tempDir.path,
        currentWorkingDirectory: workspaceDir.path,
      );
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('returns system roots when path is empty', () async {
      final snapshot = await service.browseWorkspaceTree();

      if (Platform.isWindows) {
        expect(snapshot['path'], isEmpty);
        expect(snapshot['root_path'], isEmpty);
      } else {
        expect(snapshot['path'], Platform.pathSeparator);
        expect(snapshot['root_path'], Platform.pathSeparator);
      }
      expect(snapshot['parent_path'], isNull);
      expect(snapshot['entries'], isNotEmpty);
    });

    test('allows browsing outside the daemon working directory', () async {
      final snapshot = await service.browseWorkspaceTree(path: tempDir.path);
      final normalizedTempDir = Directory(
        tempDir.path,
      ).resolveSymbolicLinksSync();

      expect(snapshot['path'], normalizedTempDir);
      final entries = snapshot['entries'] as List<dynamic>;
      expect(
        entries.any(
          (entry) =>
              entry['path'] ==
              Directory(workspaceDir.path).resolveSymbolicLinksSync(),
        ),
        isTrue,
      );
    });

    test('returns parent path for arbitrary directory navigation', () async {
      final snapshot = await service.browseWorkspaceTree(
        path: '${workspaceDir.path}/nested',
      );

      expect(
        snapshot['parent_path'],
        Directory(workspaceDir.path).resolveSymbolicLinksSync(),
      );
    });

    test('creates a workspace from path when name is omitted', () async {
      final selectedPath = '${tempDir.path}/picked-workspace';

      final workspace = await service.createWorkspace(path: selectedPath);

      expect(
        workspace['path'],
        Directory(selectedPath).resolveSymbolicLinksSync(),
      );
      expect(workspace['name'], 'picked-workspace');
    });

    group('folder mutations', () {
      test('creates one direct child and rejects traversal names', () async {
        final createdPath = await service.createFolder(
          parentPath: workspaceDir.path,
          name: 'created',
        );

        expect(Directory(createdPath).existsSync(), isTrue);
        for (final invalidName in [
          '',
          '.',
          '..',
          '../outside',
          r'nested/name',
          r'nested\name',
        ]) {
          await expectLater(
            service.createFolder(
              parentPath: workspaceDir.path,
              name: invalidName,
            ),
            throwsA(isA<FormatException>()),
          );
        }
        expect(Directory('${tempDir.path}/outside').existsSync(), isFalse);
      });

      test(
        'does not treat an existing file or folder as create success',
        () async {
          await File('${workspaceDir.path}/taken').writeAsString('content');

          await expectLater(
            service.createFolder(parentPath: workspaceDir.path, name: 'taken'),
            throwsA(isA<StateError>()),
          );
          await expectLater(
            service.createFolder(parentPath: workspaceDir.path, name: 'nested'),
            throwsA(isA<StateError>()),
          );
        },
      );

      test('renames a directory without crossing its parent', () async {
        final source = Directory('${workspaceDir.path}/source')..createSync();

        final renamedPath = await service.renameFolder(
          path: source.path,
          newName: 'renamed',
        );

        expect(source.existsSync(), isFalse);
        expect(Directory(renamedPath).existsSync(), isTrue);
        await expectLater(
          service.renameFolder(path: renamedPath, newName: '../escaped'),
          throwsA(isA<FormatException>()),
        );
      });

      test('rejects rename collisions', () async {
        final source = Directory('${workspaceDir.path}/source')..createSync();
        Directory('${workspaceDir.path}/target').createSync();

        await expectLater(
          service.renameFolder(path: source.path, newName: 'target'),
          throwsA(isA<StateError>()),
        );
        expect(source.existsSync(), isTrue);
      });

      test('deletes a directory recursively', () async {
        final target = Directory('${workspaceDir.path}/delete-me/nested')
          ..createSync(recursive: true);
        await File('${target.path}/file.txt').writeAsString('content');

        final expectedPath = target.parent.resolveSymbolicLinksSync();
        final deletedPath = await service.deleteFolder(target.parent.path);

        expect(deletedPath, expectedPath);
        expect(target.parent.existsSync(), isFalse);
      });

      test('rejects files and filesystem roots as mutable folders', () async {
        final file = await File(
          '${workspaceDir.path}/file.txt',
        ).writeAsString('content');

        await expectLater(
          service.deleteFolder(file.path),
          throwsA(isA<StateError>()),
        );
        await expectLater(
          service.deleteFolder(_fileSystemRoot(tempDir.path)),
          throwsA(isA<StateError>()),
        );
      });

      test('rejects symbolic-link folder mutation', () async {
        if (Platform.isWindows) return;
        final target = Directory('${workspaceDir.path}/target')..createSync();
        final link = Link('${workspaceDir.path}/target-link');
        await link.create(target.path);

        await expectLater(
          service.deleteFolder(link.path),
          throwsA(isA<StateError>()),
        );
        expect(target.existsSync(), isTrue);
      });
    });
  });

  test(
    'keeps stable identity while renaming and changing a missing path',
    () async {
      final stateHome = await Directory.systemTemp.createTemp(
        'sanad-workspace-identity-test',
      );
      final state = AgentStateDatabase.atPath(stateHome.path);
      final db = SessionDB.fromState(state);
      try {
        final service = LocalWorkspaceRuntimeService(
          sanadHomePath: stateHome.path,
          currentWorkingDirectory: stateHome.path,
          sessionDb: db,
        );
        final original = Directory('${stateHome.path}/original')..createSync();
        final created = await service.createWorkspace(
          path: original.path,
          name: 'Original name',
        );
        final workspaceId = created['id'] as String;
        expect(workspaceId, isNot(original.path));

        final renamed = await service.renameWorkspace(
          workspaceId: workspaceId,
          displayName: 'Renamed workspace',
        );
        expect(renamed['id'], workspaceId);
        expect(renamed['name'], 'Renamed workspace');

        original.deleteSync(recursive: true);
        final missing = (await service.listWorkspaces()).single;
        expect(missing['id'], workspaceId);
        expect(missing['availability'], 'missing');

        final replacement = Directory('${stateHome.path}/replacement')
          ..createSync();
        final relocated = await service.relocateWorkspace(
          workspaceId: workspaceId,
          newPath: replacement.path,
        );
        expect(relocated['id'], workspaceId);
        expect(relocated['path'], replacement.resolveSymbolicLinksSync());
        expect(relocated['availability'], 'available');
      } finally {
        state.dispose();
        if (stateHome.existsSync()) await stateHome.delete(recursive: true);
      }
    },
  );
}

String _fileSystemRoot(String path) {
  var current = Directory(path).absolute;
  while (current.parent.path != current.path) {
    current = current.parent;
  }
  return current.path;
}
