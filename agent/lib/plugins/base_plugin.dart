import '../core/models/message.dart';

abstract class BasePlugin {
  String get name;
  String get description;

  /// Called when a session starts.
  Future<void> onSessionStart(String sessionId) async {}

  /// Called before a message is sent to the LLM.
  /// Allows modifying the history or injecting context.
  Future<List<Message>> preExecution(List<Message> history) async => history;

  /// Called after the LLM returns a response.
  Future<void> postExecution(Message response) async {}

  /// Called when a new message is added to history (user or assistant).
  Future<void> onMessage(Message message) async {}
}
