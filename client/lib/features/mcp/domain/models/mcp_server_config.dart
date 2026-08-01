import 'package:uuid/uuid.dart';

/// نوع المصادقة للاتصال بخادم MCP
enum McpAuthType {
  oauth('OAuth'),
  noAuth('No Auth'),
  mixed('Mixed')
  ;

  final String displayName;
  const McpAuthType(this.displayName);
}

/// نوع بروتوكول النقل المكتشف
enum McpTransportType {
  streamableHttp('Streamable HTTP'),
  sse('SSE'),
  stdio('Stdio')
  ;

  final String displayName;
  const McpTransportType(this.displayName);
}

/// إعدادات خادم MCP
class McpServerConfig {
  final String id;
  final String name;
  final String? description;
  final String serverUrl; // Used for HTTP/SSE
  final McpAuthType authType;
  final String? oauthClientId;
  final String? oauthClientSecret;
  final String? oauthAuthUrl;
  final String? oauthTokenUrl;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? tokenExpiry;
  final McpTransportType? detectedTransport;
  final DateTime createdAt;
  final DateTime? lastUsedAt;
  final bool enabled;
  final List<String> disabledTools;

  // STDIO specific fields
  final String? command;
  final List<String>? args;
  final Map<String, String>? env;

  McpServerConfig({
    String? id,
    required this.name,
    this.description,
    this.serverUrl = '', // Optional for STDIO
    required this.authType,
    this.oauthClientId,
    this.oauthClientSecret,
    this.oauthAuthUrl,
    this.oauthTokenUrl,
    this.accessToken,
    this.refreshToken,
    this.tokenExpiry,
    this.detectedTransport,
    DateTime? createdAt,
    this.lastUsedAt,
    this.enabled = true,
    this.disabledTools = const [],
    this.command,
    this.args,
    this.env,
  }) : id = id ?? const Uuid().v4(),
       createdAt = createdAt ?? DateTime.now();

  /// Legacy/internal JSON representation.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'description': description,
    if (serverUrl.isNotEmpty) 'url': serverUrl,
    if (authType != McpAuthType.noAuth) 'authType': authType.name,
    'oauthClientId': oauthClientId,
    'oauthClientSecret': oauthClientSecret,
    'oauthAuthUrl': oauthAuthUrl,
    'oauthTokenUrl': oauthTokenUrl,
    if (_oauthJson case final oauth? when oauth.isNotEmpty) 'oauth': oauth,
    'accessToken': accessToken,
    'refreshToken': refreshToken,
    'tokenExpiry': tokenExpiry?.toIso8601String(),
    'detectedTransport': detectedTransport?.name,
    'createdAt': createdAt.toIso8601String(),
    'lastUsedAt': lastUsedAt?.toIso8601String(),
    if (!enabled) 'disabled': true,
    if (disabledTools.isNotEmpty) 'disabledTools': disabledTools,
    'command': command,
    'args': args,
    'env': env,
  };

  /// Canonical JSON representation for mcp_config.json files.
  Map<String, dynamic> toConfigJson() {
    final json = <String, dynamic>{};

    if (serverUrl.isNotEmpty) {
      json['url'] = serverUrl;
    }
    if (command != null && command!.trim().isNotEmpty) {
      json['command'] = command;
    }
    if (args != null && args!.isNotEmpty) {
      json['args'] = args;
    }
    if (env != null && env!.isNotEmpty) {
      json['env'] = env;
    }
    if (disabledTools.isNotEmpty) {
      json['disabledTools'] = disabledTools;
    }
    if (!enabled) {
      json['disabled'] = true;
    }
    if (_oauthJson case final oauth? when oauth.isNotEmpty) {
      json['oauth'] = oauth;
    }

    return json;
  }

  /// تحويل من JSON للتحميل
  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    final nestedOAuth = json['oauth'] as Map<String, dynamic>?;
    final detectedTransport = _parseTransport(
      detectedTransportName: json['detectedTransport'] as String?,
      hasCommand: (json['command'] as String?)?.trim().isNotEmpty == true,
      url: (json['serverUrl'] as String?) ?? (json['url'] as String?) ?? '',
    );

    return McpServerConfig(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      serverUrl: (json['serverUrl'] as String?) ?? (json['url'] as String?) ?? '',
      authType: McpAuthType.values.firstWhere(
        (e) => e.name == json['authType'],
        orElse: () => nestedOAuth != null ? McpAuthType.oauth : McpAuthType.noAuth,
      ),
      oauthClientId: (json['oauthClientId'] as String?) ?? nestedOAuth?['clientId'] as String?,
      oauthClientSecret: (json['oauthClientSecret'] as String?) ?? nestedOAuth?['clientSecret'] as String?,
      oauthAuthUrl:
          (json['oauthAuthUrl'] as String?) ??
          nestedOAuth?['authUrl'] as String? ??
          nestedOAuth?['authorizationUrl'] as String?,
      oauthTokenUrl: (json['oauthTokenUrl'] as String?) ?? nestedOAuth?['tokenUrl'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiry: json['tokenExpiry'] != null ? DateTime.parse(json['tokenExpiry'] as String) : null,
      detectedTransport: detectedTransport,
      createdAt: json['createdAt'] != null ? DateTime.parse(json['createdAt'] as String) : null,
      lastUsedAt: json['lastUsedAt'] != null ? DateTime.parse(json['lastUsedAt'] as String) : null,
      enabled: json['disabled'] != true,
      disabledTools: (json['disabledTools'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? const [],
      command: json['command'] as String?,
      args: (json['args'] as List<dynamic>?)?.map((e) => e as String).toList(),
      env: (json['env'] as Map<String, dynamic>?)?.map((k, v) => MapEntry(k, v as String)),
    );
  }

  /// إنشاء نسخة معدلة
  McpServerConfig copyWith({
    String? name,
    String? description,
    String? serverUrl,
    McpAuthType? authType,
    String? oauthClientId,
    String? oauthClientSecret,
    String? oauthAuthUrl,
    String? oauthTokenUrl,
    String? accessToken,
    String? refreshToken,
    DateTime? tokenExpiry,
    McpTransportType? detectedTransport,
    DateTime? lastUsedAt,
    bool? enabled,
    List<String>? disabledTools,
    String? command,
    List<String>? args,
    Map<String, String>? env,
  }) {
    return McpServerConfig(
      id: id,
      name: name ?? this.name,
      description: description ?? this.description,
      serverUrl: serverUrl ?? this.serverUrl,
      authType: authType ?? this.authType,
      oauthClientId: oauthClientId ?? this.oauthClientId,
      oauthClientSecret: oauthClientSecret ?? this.oauthClientSecret,
      oauthAuthUrl: oauthAuthUrl ?? this.oauthAuthUrl,
      oauthTokenUrl: oauthTokenUrl ?? this.oauthTokenUrl,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      tokenExpiry: tokenExpiry ?? this.tokenExpiry,
      detectedTransport: detectedTransport ?? this.detectedTransport,
      createdAt: createdAt,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      enabled: enabled ?? this.enabled,
      disabledTools: disabledTools ?? this.disabledTools,
      command: command ?? this.command,
      args: args ?? this.args,
      env: env ?? this.env,
    );
  }

  @override
  String toString() =>
      'McpServerConfig(name: $name, url: $serverUrl, auth: ${authType.displayName}, transport: $detectedTransport)';

  bool isToolDisabled(String toolName) {
    return disabledTools.contains(toolName.trim());
  }

  Map<String, dynamic>? get _oauthJson {
    final oauth = <String, dynamic>{};
    if (oauthClientId != null && oauthClientId!.isNotEmpty) {
      oauth['clientId'] = oauthClientId;
    }
    if (oauthClientSecret != null && oauthClientSecret!.isNotEmpty) {
      oauth['clientSecret'] = oauthClientSecret;
    }
    if (oauthAuthUrl != null && oauthAuthUrl!.isNotEmpty) {
      oauth['authUrl'] = oauthAuthUrl;
    }
    if (oauthTokenUrl != null && oauthTokenUrl!.isNotEmpty) {
      oauth['tokenUrl'] = oauthTokenUrl;
    }
    return oauth.isEmpty ? null : oauth;
  }

  static McpTransportType? _parseTransport({
    required String? detectedTransportName,
    required bool hasCommand,
    required String url,
  }) {
    if (detectedTransportName != null) {
      for (final value in McpTransportType.values) {
        if (value.name == detectedTransportName) {
          return value;
        }
      }
    }

    if (hasCommand) {
      return McpTransportType.stdio;
    }

    if (url.trim().isNotEmpty) {
      return McpTransportType.streamableHttp;
    }

    return null;
  }
}
