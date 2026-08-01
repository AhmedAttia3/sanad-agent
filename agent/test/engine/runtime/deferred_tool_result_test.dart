import 'dart:convert';

import 'package:sanad_agent/engine/runtime/deferred_tool_result.dart';
import 'package:test/test.dart';

void main() {
  const descriptor = DeferredToolResultDescriptor(
    kind: DeferredToolResultDescriptor.supportedKind,
    transactionId: 'switch-1',
    manifestPath: '/tmp/sanad-test-home/dev/runtime-switch-58085.json',
    requesterSessionId: 'session-1',
    requesterToolCallId: 'tool-1',
  );

  test('parses a shell tool deferred-result envelope', () {
    final raw = jsonEncode({
      'isError': false,
      'output': jsonEncode({
        DeferredToolResultDescriptor.envelopeKey: descriptor.toJson(),
      }),
    });

    expect(
      DeferredToolResultDescriptor.tryParseToolResult(
        raw,
        sessionId: 'session-1',
        toolCallId: 'tool-1',
      )?.transactionId,
      'switch-1',
    );
    expect(
      DeferredToolResultDescriptor.tryParseToolResult(
        raw,
        sessionId: 'another-session',
        toolCallId: 'tool-1',
      ),
      isNull,
    );
  });

  for (final testCase in const [
    (status: 'complete', contains: 'Switch complete', isError: false),
    (status: 'rolled_back', contains: 'Switch rolled back', isError: false),
    (
      status: 'failed',
      contains: 'Error: Runtime source switch failed',
      isError: true,
    ),
    (
      status: 'recovery_failed',
      contains: 'could not be restored',
      isError: true,
    ),
  ]) {
    test('resolves terminal ${testCase.status} manifest', () async {
      final resolver = DeferredToolResultResolver(
        environment: const {'SANAD_HOME': '/tmp/sanad-test-home'},
        readManifest: (_) async => jsonEncode({
          'id': 'switch-1',
          'requester_session_id': 'session-1',
          'requester_tool_call_id': 'tool-1',
          'target_worktree_name': 'target-worktree',
          'status': testCase.status,
          'message': 'terminal detail',
        }),
      );

      final result = await resolver.resolve(descriptor);

      expect(result.output, contains(testCase.contains));
      expect(result.output, contains('terminal detail'));
      expect(result.isError, testCase.isError);
    });
  }

  test('rejects a manifest path outside the active Sanad Home', () async {
    final resolver = DeferredToolResultResolver(
      environment: const {'SANAD_HOME': '/tmp/another-home'},
      readManifest: (_) async => '{}',
    );

    final result = await resolver.resolve(descriptor);
    expect(result.isError, isTrue);
    expect(result.output, contains('outside the active Sanad Home'));
  });

  test('identity mismatch fails immediately without polling', () async {
    var reads = 0;
    final resolver = DeferredToolResultResolver(
      environment: const {'SANAD_HOME': '/tmp/sanad-test-home'},
      readManifest: (_) async {
        reads++;
        return jsonEncode(const {
          'id': 'another-switch',
          'requester_session_id': 'session-1',
          'requester_tool_call_id': 'tool-1',
          'status': 'complete',
        });
      },
    );

    final result = await resolver.resolve(descriptor);
    expect(result.isError, isTrue);
    expect(result.output, contains('identity does not match'));
    expect(reads, 1);
  });
}
