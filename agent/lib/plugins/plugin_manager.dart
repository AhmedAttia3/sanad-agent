import '../core/models/message.dart';
import 'base_plugin.dart';

class PluginManager {
  final List<BasePlugin> _plugins = [];

  void registerPlugin(BasePlugin plugin) {
    _plugins.add(plugin);
  }

  Future<void> notifySessionStart(String sessionId) async {
    for (var plugin in _plugins) {
      await plugin.onSessionStart(sessionId);
    }
  }

  Future<List<Message>> runPreExecution(List<Message> history) async {
    var modifiedHistory = List<Message>.from(history);
    for (var plugin in _plugins) {
      modifiedHistory = await plugin.preExecution(modifiedHistory);
    }
    return modifiedHistory;
  }

  Future<void> runPostExecution(Message response) async {
    for (var plugin in _plugins) {
      await plugin.postExecution(response);
    }
  }

  Future<void> notifyMessage(Message message) async {
    for (var plugin in _plugins) {
      await plugin.onMessage(message);
    }
  }
}
