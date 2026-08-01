class LocalToolSpec {
  final String name;
  final String displayName;
  final String description;
  final Map<String, dynamic> inputSchema;
  final Map<String, dynamic> source;
  final String category;
  final bool workspaceRequired;
  final Map<String, dynamic> approval;
  final Map<String, dynamic> execution;
  final Map<String, dynamic> availability;
  final String? serverName;

  const LocalToolSpec({
    required this.name,
    required this.displayName,
    required this.description,
    required this.inputSchema,
    required this.source,
    required this.category,
    required this.workspaceRequired,
    required this.approval,
    required this.execution,
    this.availability = const {'status': 'available'},
    this.serverName,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'display_name': displayName,
    'description': description,
    'input_schema': inputSchema,
    'source': source,
    'category': category,
    'workspace_required': workspaceRequired,
    'approval': approval,
    'execution': execution,
    'availability': availability,
    if (serverName != null) 'server_name': serverName,
  };

  Map<String, dynamic> toRegisterPayload() => {
    'name': name,
    'description': description,
    'input_schema': inputSchema,
    if (serverName != null) 'server_name': serverName,
  };
}
