import 'package:test/test.dart';
import 'package:sanad_agent/core/models/message.dart';
import 'package:sanad_agent/plugins/base_plugin.dart';
import 'package:sanad_agent/plugins/plugin_manager.dart';

class MockPlugin extends BasePlugin {
  bool onMessageCalled = false;
  bool preExecutionCalled = false;

  @override
  String get name => 'Mock';

  @override
  String get description => 'Mock Plugin';

  @override
  Future<void> onMessage(Message message) async {
    onMessageCalled = true;
  }

  @override
  Future<List<Message>> preExecution(List<Message> history) async {
    preExecutionCalled = true;
    return history;
  }
}

void main() {
  group('Plugin System', () {
    test('PluginManager calls hooks', () async {
      final manager = PluginManager();
      final mock = MockPlugin();
      manager.registerPlugin(mock);

      await manager.notifyMessage(
        Message(role: MessageRole.user, content: 'test'),
      );
      expect(mock.onMessageCalled, isTrue);

      await manager.runPreExecution([]);
      expect(mock.preExecutionCalled, isTrue);
    });
  });
}
