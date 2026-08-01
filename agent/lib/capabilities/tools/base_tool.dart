import '../models/tool_schema.dart';

abstract class BaseTool {
  ToolSchema get schema;

  /// Whether this tool may be safely re-executed after a daemon crash/restart
  /// when the runtime cannot prove whether the previous execution completed.
  ///
  /// Defaults to false. Tools must opt in explicitly from their own contract;
  /// the runtime must not maintain ad-hoc allow-lists for replay safety.
  bool get restartReplaySafe => false;

  Future<String> execute(Map<String, dynamic> args, {ToolContext? context});
}

class ToolContext {
  final String sessionId;
  final Map<String, dynamic> metadata;
  final String? toolCallId;

  ToolContext({
    required this.sessionId,
    this.metadata = const {},
    this.toolCallId,
  });
}
