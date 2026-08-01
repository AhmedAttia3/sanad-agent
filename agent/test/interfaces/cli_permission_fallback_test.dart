import 'package:sanad_agent/interfaces/runtime/platform_runtime_bridge.dart';
import 'package:test/test.dart';

void main() {
  test(
    'PlatformRuntimeBridge uses registered local permission handler fallback',
    () async {
      final bridge = PlatformRuntimeBridge();
      bridge.registerSessionHandlers(
        'cli-session',
        permissionHandler: (payload) async {
          return {
            'request_id': payload['request_id'],
            'allowed': true,
            'scope': 'session',
            'decision': 'allow',
          };
        },
      );

      final result = await bridge.requestToolPermission(
        sessionId: 'cli-session',
        payload: {'request_id': 'req-cli-1', 'tool_name': 'shell_execute'},
      );

      expect(result['allowed'], isTrue);
      expect(result['scope'], equals('session'));
      expect(result['decision'], equals('allow'));
    },
  );
}
