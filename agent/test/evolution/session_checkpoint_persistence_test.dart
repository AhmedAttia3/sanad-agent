import 'dart:io';

import 'package:sanad_agent/core/constants.dart';
import 'package:sanad_agent/evolution/models/suspended_checkpoint.dart';
import 'package:sanad_agent/evolution/session_manager.dart';
import 'package:test/test.dart';

void main() {
  group('Suspended checkpoint persistence', () {
    late Directory tempDir;
    late SessionManager sessionManager;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'session-checkpoint-persistence-test',
      );
      SessionManager.resetForTesting();
      setSanadHomeOverride(tempDir.path);
      sessionManager = SessionManager();
    });

    tearDown(() async {
      SessionManager.resetForTesting();
      setSanadHomeOverride(null);
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'round-trips suspended checkpoints through sqlite across manager restart',
      () {
        final checkpoint = SuspendedCheckpoint(
          checkpointId: 'checkpoint-1',
          sessionId: 'session-1',
          requestId: 'permission-123',
          toolCallId: 'tool-call-1',
          toolName: 'shell_execute',
          status: 'awaiting_permission',
          toolArguments: {'command': 'echo hello'},
          permissionPayload: {
            'tool_name': 'shell_execute',
            'session_id': 'session-1',
          },
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
        );

        sessionManager.saveSuspendedCheckpoint(checkpoint);

        SessionManager.resetForTesting();
        final restartedSessionManager = SessionManager();

        final restored = restartedSessionManager
            .getSuspendedCheckpointByRequestId('permission-123');
        expect(restored, isNotNull);
        expect(restored!.toolCallId, equals('tool-call-1'));
        expect(restored.toolArguments['command'], equals('echo hello'));
        expect(restored.status, equals('awaiting_permission'));

        expect(
          restartedSessionManager.claimSuspendedCheckpointDecision(
            requestId: 'permission-123',
            status: 'resuming',
          ),
          isTrue,
        );
        expect(
          restartedSessionManager.claimSuspendedCheckpointDecision(
            requestId: 'permission-123',
            status: 'denied',
          ),
          isFalse,
        );
        final updated = restartedSessionManager
            .getSuspendedCheckpointByRequestId('permission-123');
        expect(updated?.status, equals('resuming'));

        restartedSessionManager.deleteSuspendedCheckpointByToolCallId(
          'tool-call-1',
        );
        final deleted = restartedSessionManager
            .getSuspendedCheckpointByRequestId('permission-123');
        expect(deleted, isNull);
      },
    );
  });
}
