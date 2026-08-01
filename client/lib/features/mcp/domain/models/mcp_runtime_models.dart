import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';

enum McpConfigScope { global, workspace, effective }

extension McpConfigScopeWire on McpConfigScope {
  String get wireValue => switch (this) {
    McpConfigScope.global => 'global',
    McpConfigScope.workspace => 'workspace',
    McpConfigScope.effective => 'effective',
  };
}

class McpRuntimeServerEntry {
  const McpRuntimeServerEntry({
    required this.name,
    required this.source,
    required this.config,
    this.workspaceId,
  });

  final String name;
  final String source;
  final McpServerConfig config;
  final String? workspaceId;

  factory McpRuntimeServerEntry.fromJson(Map<String, dynamic> json) {
    final configJson = Map<String, dynamic>.from(json['config'] as Map? ?? const {});
    configJson.putIfAbsent('name', () => json['name']?.toString() ?? '');
    return McpRuntimeServerEntry(
      name: json['name']?.toString() ?? '',
      source: json['source']?.toString() ?? 'unknown',
      workspaceId: json['workspace_id']?.toString(),
      config: McpServerConfig.fromJson(configJson),
    );
  }
}

class McpRuntimeSection {
  const McpRuntimeSection({
    required this.scope,
    required this.document,
    required this.servers,
  });

  final McpConfigScope scope;
  final Map<String, dynamic> document;
  final List<McpRuntimeServerEntry> servers;

  factory McpRuntimeSection.fromJson(Map<String, dynamic> json) {
    final scopeName = json['scope']?.toString() ?? 'effective';
    final scope = McpConfigScope.values.firstWhere(
      (value) => value.wireValue == scopeName,
      orElse: () => McpConfigScope.effective,
    );
    final servers = (json['servers'] as List? ?? const [])
        .whereType<Map>()
        .map((entry) => McpRuntimeServerEntry.fromJson(Map<String, dynamic>.from(entry)))
        .toList(growable: false);
    return McpRuntimeSection(
      scope: scope,
      document: Map<String, dynamic>.from(json['document'] as Map? ?? const {'mcpServers': {}}),
      servers: servers,
    );
  }
}

class McpRuntimeSnapshot {
  const McpRuntimeSnapshot({
    required this.global,
    required this.workspace,
    required this.effective,
    this.workspaceId,
  });

  final String? workspaceId;
  final McpRuntimeSection global;
  final McpRuntimeSection workspace;
  final McpRuntimeSection effective;

  factory McpRuntimeSnapshot.fromJson(Map<String, dynamic> json) {
    return McpRuntimeSnapshot(
      workspaceId: json['workspace_id']?.toString(),
      global: McpRuntimeSection.fromJson(Map<String, dynamic>.from(json['global'] as Map? ?? const {})),
      workspace: McpRuntimeSection.fromJson(Map<String, dynamic>.from(json['workspace'] as Map? ?? const {})),
      effective: McpRuntimeSection.fromJson(Map<String, dynamic>.from(json['effective'] as Map? ?? const {})),
    );
  }
}

class McpRuntimeTool {
  const McpRuntimeTool({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, dynamic> inputSchema;

  factory McpRuntimeTool.fromJson(Map<String, dynamic> json) {
    return McpRuntimeTool(
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      inputSchema: Map<String, dynamic>.from(json['input_schema'] as Map? ?? const {}),
    );
  }
}

class McpServerInspection {
  const McpServerInspection({
    required this.name,
    required this.success,
    required this.tools,
    this.scope = McpConfigScope.effective,
    this.workspaceId,
    this.error,
  });

  final String name;
  final bool success;
  final List<McpRuntimeTool> tools;
  final McpConfigScope scope;
  final String? workspaceId;
  final String? error;

  factory McpServerInspection.fromJson(Map<String, dynamic> json) {
    final scopeName = json['scope']?.toString() ?? 'effective';
    return McpServerInspection(
      name: json['name']?.toString() ?? '',
      success: json['success'] == true,
      error: json['error']?.toString(),
      workspaceId: json['workspace_id']?.toString(),
      scope: McpConfigScope.values.firstWhere(
        (value) => value.wireValue == scopeName,
        orElse: () => McpConfigScope.effective,
      ),
      tools: (json['tools'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => McpRuntimeTool.fromJson(Map<String, dynamic>.from(entry)))
          .toList(growable: false),
    );
  }
}
