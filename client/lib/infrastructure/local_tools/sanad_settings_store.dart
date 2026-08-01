import 'dart:convert';
import 'dart:io';

import 'package:sanad_client/core/config/app_config.dart';
import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';

class SanadSettingsStore {
  const SanadSettingsStore({
    this.homeDirectoryPath,
    this.sanadHomePath,
  });

  final String? homeDirectoryPath;
  final String? sanadHomePath;

  Future<List<McpServerConfig>> readUserMcpServers() async {
    final settings = await readUserMcpConfigDocument();
    return parseMcpServersDocument(settings);
  }

  Future<List<McpServerConfig>> readWorkspaceMcpServers(String workspacePath) async {
    final settings = await readWorkspaceMcpConfigDocument(workspacePath);
    return parseMcpServersDocument(settings);
  }

  Future<List<McpServerConfig>> readEffectiveMcpServers({String? workspacePath}) async {
    final merged = <String, McpServerConfig>{};

    for (final server in await readUserMcpServers()) {
      merged[server.name] = server;
    }

    final normalizedWorkspacePath = _normalizeWorkspacePath(workspacePath);
    if (normalizedWorkspacePath != null) {
      for (final server in await readWorkspaceMcpServers(normalizedWorkspacePath)) {
        merged[server.name] = server;
      }
    }

    return merged.values.toList(growable: false);
  }

  Future<void> saveUserMcpServers(List<McpServerConfig> servers) async {
    final file = _userMcpConfigFile();
    await _writeSettingsMap(file, encodeMcpServersDocument(servers));
  }

  Future<void> saveWorkspaceMcpServers(
    String workspacePath,
    List<McpServerConfig> servers,
  ) async {
    final file = _workspaceMcpConfigFile(workspacePath);
    await _writeSettingsMap(file, encodeMcpServersDocument(servers));
  }

  static File mcpConfigFileForWorkspace(String workspacePath) {
    final normalizedPath = _normalizeWorkspacePath(workspacePath) ?? workspacePath.trim();
    return File('$normalizedPath${Platform.pathSeparator}.sanad${Platform.pathSeparator}mcp_config.json');
  }

  Future<Map<String, dynamic>> _readSettingsMap(File file) async {
    if (!await file.exists()) {
      return <String, dynamic>{};
    }

    final raw = await file.readAsString();
    if (raw.trim().isEmpty) {
      return <String, dynamic>{};
    }

    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Sanad settings must be a JSON object.');
    }
    return decoded;
  }

  Future<Map<String, dynamic>> readUserMcpConfigDocument() async {
    return _readSettingsMap(_userMcpConfigFile());
  }

  Future<Map<String, dynamic>> readWorkspaceMcpConfigDocument(String workspacePath) async {
    return _readSettingsMap(_workspaceMcpConfigFile(workspacePath));
  }

  Future<Map<String, dynamic>> readEffectiveMcpConfigDocument({String? workspacePath}) async {
    return encodeMcpServersDocument(
      await readEffectiveMcpServers(workspacePath: workspacePath),
    );
  }

  Future<void> _writeSettingsMap(File file, Map<String, dynamic> settings) async {
    await file.parent.create(recursive: true);
    await file.writeAsString(
      const JsonEncoder.withIndent('  ').convert(settings),
    );
    await _secureFileIfSensitive(file);
  }

  Future<void> _secureFileIfSensitive(File file) async {
    if (Platform.isWindows || file.path != _authFile().path) return;
    await Process.run('chmod', ['600', file.path]);
  }

  File _userMcpConfigFile() {
    final sanadHome = _resolveSanadHomeDirectory();
    return File('$sanadHome${Platform.pathSeparator}mcp_config.json');
  }

  File _workspaceMcpConfigFile(String workspacePath) {
    return mcpConfigFileForWorkspace(workspacePath);
  }

  Future<Map<String, dynamic>> readAuthDocument() async {
    return _readSettingsMap(_authFile());
  }

  Future<void> saveAuthDocument(Map<String, dynamic> authData) async {
    await _writeSettingsMap(_authFile(), authData);
  }

  Future<void> deleteAuthDocument() async {
    final file = _authFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  File _authFile() {
    final sanadHome = _resolveSanadHomeDirectory();
    return File('$sanadHome${Platform.pathSeparator}auth.json');
  }

  String _resolveSanadHomeDirectory() {
    final explicitSanadHome = sanadHomePath?.trim();
    if (explicitSanadHome != null && explicitSanadHome.isNotEmpty) {
      return explicitSanadHome;
    }
    if (AppConfig.sanadHome.trim().isNotEmpty) {
      return AppConfig.sanadHome.trim();
    }
    return '${_resolveHomeDirectory()}${Platform.pathSeparator}.sanad';
  }

  String _resolveHomeDirectory() {
    final explicitPath = homeDirectoryPath?.trim();
    if (explicitPath != null && explicitPath.isNotEmpty) {
      return explicitPath;
    }

    final environment = Platform.environment;
    final home = environment['HOME']?.trim();
    if (home != null && home.isNotEmpty) {
      return home;
    }

    final userProfile = environment['USERPROFILE']?.trim();
    if (userProfile != null && userProfile.isNotEmpty) {
      return userProfile;
    }

    final homeDrive = environment['HOMEDRIVE']?.trim();
    final homePath = environment['HOMEPATH']?.trim();
    if (homeDrive != null && homeDrive.isNotEmpty && homePath != null && homePath.isNotEmpty) {
      return '$homeDrive$homePath';
    }

    throw const FileSystemException('Unable to resolve the user home directory for ~/.sanad settings.');
  }

  static String? _normalizeWorkspacePath(String? workspacePath) {
    final trimmed = workspacePath?.trim();
    if (trimmed == null || trimmed.isEmpty) {
      return null;
    }

    final directory = Directory(trimmed);
    try {
      return directory.resolveSymbolicLinksSync();
    } catch (_) {
      return directory.absolute.path;
    }
  }

  List<McpServerConfig> parseMcpServersDocument(Map<String, dynamic> document) {
    return _parseMcpServers(document['mcpServers']);
  }

  Map<String, dynamic> encodeMcpServersDocument(List<McpServerConfig> servers) {
    return {
      'mcpServers': _encodeMcpServers(servers),
    };
  }

  List<McpServerConfig> _parseMcpServers(dynamic rawValue) {
    if (rawValue is List) {
      return rawValue
          .whereType<Map>()
          .map((item) => McpServerConfig.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    if (rawValue is! Map) {
      return const [];
    }

    final configs = <McpServerConfig>[];
    for (final entry in rawValue.entries) {
      if (entry.value is! Map) {
        continue;
      }
      final json = Map<String, dynamic>.from(entry.value as Map);
      json.putIfAbsent('name', () => entry.key.toString());
      configs.add(McpServerConfig.fromJson(json));
    }
    return configs;
  }

  Map<String, dynamic> _encodeMcpServers(List<McpServerConfig> servers) {
    final encoded = <String, dynamic>{};
    for (final server in servers) {
      encoded[server.name] = server.toConfigJson();
    }
    return encoded;
  }
}
