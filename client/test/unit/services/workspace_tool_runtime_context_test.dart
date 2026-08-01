import 'package:sanad_client/infrastructure/local_tools/workspace_tool_runtime_context.dart';
import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('WorkspaceToolRuntimeContext', () {
    late WorkspaceToolRuntimeContext context;
    final workspace = DeviceWorkspace(id: 'w1', name: 'Test Workspace', path: '/path/to/ws', trustState: 'trusted');

    setUp(() {
      context = WorkspaceToolRuntimeContext();
    });

    test('should bind and unbind session workspace', () {
      context.bindSessionWorkspace('session1', workspace);
      expect(context.workspaceForSession('session1'), workspace);

      context.unbindSession('session1');
      context.setActiveWorkspace(null); // Clear fallback
      expect(context.workspaceForSession('session1'), isNull);
    });

    test('should handle session-level permissions', () {
      const sessionId = 'session1';
      const approvalKey = 'shell_execute:ls';

      expect(context.isAllowedForSession(sessionId, approvalKey), isFalse);

      context.allowForSession(sessionId, approvalKey);
      expect(context.isAllowedForSession(sessionId, approvalKey), isTrue);

      // Should not be allowed for another session
      expect(context.isAllowedForSession('session2', approvalKey), isFalse);

      // Should not be allowed for another key
      expect(context.isAllowedForSession(sessionId, 'other.key'), isFalse);
    });

    test('should clear session permissions when unbinding session', () {
      const sessionId = 'session1';
      const approvalKey = 'shell_execute:ls';

      context.allowForSession(sessionId, approvalKey);
      expect(context.isAllowedForSession(sessionId, approvalKey), isTrue);

      context.unbindSession(sessionId);
      expect(context.isAllowedForSession(sessionId, approvalKey), isFalse);
    });

    test('should clear everything on clear()', () {
      context.bindSessionWorkspace('session1', workspace);
      context.allowForSession('session1', 'key1');
      context.setActiveWorkspace(workspace);

      context.clear();

      expect(context.activeWorkspace, isNull);
      expect(context.workspaceForSession('session1'), isNull);
      expect(context.isAllowedForSession('session1', 'key1'), isFalse);
    });
  });
}
