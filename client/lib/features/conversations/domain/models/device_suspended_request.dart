class DeviceSuspendedRequest {
  final String requestId;
  final String sessionId;
  final String toolName;
  final String permissionClass;
  final String scope;
  final String? workspaceId;
  final String? workspaceName;
  final String? workspacePath;
  final Map<String, dynamic> toolInput;
  final Map<String, dynamic> tool;

  const DeviceSuspendedRequest({
    required this.requestId,
    required this.sessionId,
    required this.toolName,
    required this.permissionClass,
    required this.scope,
    required this.workspaceId,
    required this.workspaceName,
    required this.workspacePath,
    required this.toolInput,
    required this.tool,
  });

  factory DeviceSuspendedRequest.fromJson(Map<String, dynamic> json) {
    final toolInputMap = Map<String, dynamic>.from(
      json['tool_input'] as Map? ?? const {},
    );
    if (json.containsKey('questions')) {
      toolInputMap['questions'] = json['questions'];
    }
    if (json.containsKey('question')) {
      toolInputMap['question'] = json['question'];
    }
    return DeviceSuspendedRequest(
      requestId: json['request_id']?.toString() ?? '',
      sessionId: json['session_id']?.toString() ?? '',
      toolName: json['tool_name']?.toString() ?? '',
      permissionClass: json['permission_class']?.toString() ?? '',
      scope: json['scope']?.toString() ?? 'once',
      workspaceId: json['workspace_id']?.toString(),
      workspaceName: json['workspace_name']?.toString(),
      workspacePath: json['workspace_path']?.toString(),
      toolInput: toolInputMap,
      tool: Map<String, dynamic>.from(json['tool'] as Map? ?? const {}),
    );
  }

  Map<String, dynamic> toJson() => {
    'request_id': requestId,
    'session_id': sessionId,
    'tool_name': toolName,
    'permission_class': permissionClass,
    'scope': scope,
    'workspace_id': workspaceId,
    'workspace_name': workspaceName,
    'workspace_path': workspacePath,
    'tool_input': toolInput,
    'tool': tool,
  };

  String? get commandPreview => toolInput['command']?.toString();

  List<Map<String, dynamic>> get questions {
    final raw = toolInput['questions'] ?? tool['questions'] ?? toJson()['questions'];
    if (raw is List) {
      return List<Map<String, dynamic>>.from(
        raw.map((q) => Map<String, dynamic>.from(q as Map)),
      );
    }
    // Fallback to single question (backward compatibility)
    final singleQuestion = toolInput['question']?.toString() ?? toJson()['question']?.toString() ?? '';
    if (singleQuestion.isNotEmpty) {
      return [
        {
          'question': singleQuestion,
          'options': <String>[],
        },
      ];
    }
    return const [];
  }

  String get scopeLabel {
    switch (scope) {
      case 'workspace':
        return 'workspace';
      case 'session':
        return 'session';
      default:
        return 'once';
    }
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is DeviceSuspendedRequest &&
        other.requestId == requestId &&
        other.sessionId == sessionId &&
        other.toolName == toolName &&
        other.permissionClass == permissionClass &&
        other.scope == scope &&
        other.workspaceId == workspaceId &&
        other.workspaceName == workspaceName &&
        other.workspacePath == workspacePath;
  }

  @override
  int get hashCode => Object.hash(
    requestId,
    sessionId,
    toolName,
    permissionClass,
    scope,
    workspaceId,
    workspaceName,
    workspacePath,
  );
}
