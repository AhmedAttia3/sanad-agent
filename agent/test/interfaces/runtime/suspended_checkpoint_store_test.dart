import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sanad_agent/core/constants.dart';
import 'package:sanad_agent/evolution/session_manager.dart';
import 'package:sanad_agent/interfaces/runtime/suspended_checkpoint_store.dart';
import 'package:test/test.dart';

void main() {
  group('SuspendedCheckpointStore', () {
    late Directory tempDir;
    late File databaseFile;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'suspended-checkpoint-store-test',
      );
      databaseFile = File(p.join(tempDir.path, 'state.db'));
      SessionManager.resetForTesting();
      setSanadStateHomeOverride(tempDir.path);
    });

    tearDown(() async {
      SessionManager.resetForTesting();
      setSanadStateHomeOverride(null);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('opens sqlite only when persistence is first requested', () async {
      final store = SuspendedCheckpointStore();

      expect(databaseFile.existsSync(), isFalse);

      expect(await store.listAwaitingPermission(), isEmpty);
      expect(databaseFile.existsSync(), isTrue);
    });
  });
}
