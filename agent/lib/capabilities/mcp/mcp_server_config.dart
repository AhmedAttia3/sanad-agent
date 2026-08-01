import 'package:uuid/uuid.dart';

enum McpAuthType {
  oauth('OAuth'),
  noAuth('No Auth'),
  mixed('Mixed');

  final String displayName;
  const McpAuthType(this.displayName);
}

enum McpTransportType {
  streamableHttp('Streamable HTTP'),
  sse('SSE'),
  stdio('Stdio');

  final String displayName;
  const McpTransportType(this.displayName);
}

class McpServerConfig {
  final String id;
  final String name;
  final String? description;
  final String serverUrl;
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
  final String? command;
  final List<String>? args;
  final Map<String, String>? env;

  McpServerConfig({
    String? id,
    required this.name,
    this.description,
    this.serverUrl = '',
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
    final oauth = _oauthJson;
    if (oauth != null && oauth.isNotEmpty) {
      json['oauth'] = oauth;
    }
    return json;
  }

  factory McpServerConfig.fromJson(Map<String, dynamic> json) {
    final nestedOAuth = json['oauth'] is Map
        ? Map<String, dynamic>.from(json['oauth'] as Map)
        : null;
    return McpServerConfig(
      id: json['id'] as String?,
      name: json['name'] as String,
      description: json['description'] as String?,
      serverUrl:
          (json['serverUrl'] as String?) ?? (json['url'] as String?) ?? '',
      authType: McpAuthType.values.firstWhere(
        (value) => value.name == json['authType'],
        orElse: () =>
            nestedOAuth != null ? McpAuthType.oauth : McpAuthType.noAuth,
      ),
      oauthClientId:
          (json['oauthClientId'] as String?) ??
          nestedOAuth?['clientId'] as String?,
      oauthClientSecret:
          (json['oauthClientSecret'] as String?) ??
          nestedOAuth?['clientSecret'] as String?,
      oauthAuthUrl:
          (json['oauthAuthUrl'] as String?) ??
          nestedOAuth?['authUrl'] as String? ??
          nestedOAuth?['authorizationUrl'] as String?,
      oauthTokenUrl:
          (json['oauthTokenUrl'] as String?) ??
          nestedOAuth?['tokenUrl'] as String?,
      accessToken: json['accessToken'] as String?,
      refreshToken: json['refreshToken'] as String?,
      tokenExpiry: json['tokenExpiry'] != null
          ? DateTime.parse(json['tokenExpiry'] as String)
          : null,
      detectedTransport: _parseTransport(
        detectedTransportName: json['detectedTransport'] as String?,
        hasCommand: (json['command'] as String?)?.trim().isNotEmpty == true,
        url: (json['serverUrl'] as String?) ?? (json['url'] as String?) ?? '',
      ),
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastUsedAt: json['lastUsedAt'] != null
          ? DateTime.parse(json['lastUsedAt'] as String)
          : null,
      enabled: json['disabled'] != true,
      disabledTools:
          (json['disabledTools'] as List<dynamic>?)
              ?.map((value) => value.toString())
              .toList() ??
          const [],
      command: json['command'] as String?,
      args: (json['args'] as List<dynamic>?)
          ?.map((value) => value.toString())
          .toList(),
      env: (json['env'] as Map?)?.map(
        (key, value) => MapEntry(key.toString(), value.toString()),
      ),
    );
  }

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
