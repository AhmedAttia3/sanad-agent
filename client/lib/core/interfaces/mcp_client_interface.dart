import 'package:mcp_client/mcp_client.dart';

abstract class IMcpClient {
  Future<CallToolResult> callTool(String name, Map<String, dynamic> args);
  Future<List<Tool>> listTools();
  void disconnect();
}
