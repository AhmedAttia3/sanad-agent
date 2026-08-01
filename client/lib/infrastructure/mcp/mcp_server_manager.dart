import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:sanad_client/features/mcp/domain/models/mcp_server_config.dart';
import 'package:sanad_client/infrastructure/local_tools/sanad_settings_store.dart';

/// مدير خوادم MCP - للحفظ والتحميل من ملف إعدادات Sanad
class McpServerManager {
  static const String _legacyStorageKey = 'mcp_servers';

  McpServerManager(
    this._prefs, {
    SanadSettingsStore settingsStore = const SanadSettingsStore(),
  }) : _settingsStore = settingsStore;

  final SharedPreferences _prefs;
  final SanadSettingsStore _settingsStore;
  bool _legacyMigrationChecked = false;

  /// إنشاء instance من المدير
  static Future<McpServerManager> create() async {
    final prefs = await SharedPreferences.getInstance();
    return McpServerManager(prefs);
  }

  /// حفظ خادم جديد
  Future<void> saveServer(
    McpServerConfig config, {
    String? workspacePath,
  }) async {
    final servers = List<McpServerConfig>.from(
      await loadServers(workspacePath: workspacePath),
    );

    final existingIndex = servers.indexWhere(
      (s) =>
          s.id == config.id ||
          s.name == config.name ||
          (config.serverUrl.trim().isNotEmpty && s.serverUrl == config.serverUrl),
    );

    if (existingIndex >= 0) {
      servers[existingIndex] = config;
    } else {
      servers.add(config);
    }

    await _saveServers(servers, workspacePath: workspacePath);
  }

  /// تحميل جميع الخوادم المحفوظة
  Future<List<McpServerConfig>> loadServers({
    String? workspacePath,
  }) async {
    if (workspacePath == null || workspacePath.trim().isEmpty) {
      await _migrateLegacyPrefsIfNeeded();
      return _settingsStore.readUserMcpServers();
    }
    return _settingsStore.readWorkspaceMcpServers(workspacePath);
  }

  /// حذف خادم
  Future<void> deleteServer(
    String id, {
    String? workspacePath,
  }) async {
    final servers = List<McpServerConfig>.from(
      await loadServers(workspacePath: workspacePath),
    );
    servers.removeWhere((s) => s.id == id);
    await _saveServers(servers, workspacePath: workspacePath);
  }

  /// تحديث خادم موجود
  Future<void> updateServer(
    McpServerConfig config, {
    String? workspacePath,
  }) async {
    await saveServer(config, workspacePath: workspacePath);
  }

  /// تحديث وقت آخر استخدام
  Future<void> updateLastUsed(
    String id, {
    String? workspacePath,
  }) async {
    final servers = List<McpServerConfig>.from(
      await loadServers(workspacePath: workspacePath),
    );
    final index = servers.indexWhere((s) => s.id == id);

    if (index >= 0) {
      servers[index] = servers[index].copyWith(lastUsedAt: DateTime.now());
      await _saveServers(servers, workspacePath: workspacePath);
    }
  }

  /// حذف جميع الخوادم
  Future<void> clearAll({String? workspacePath}) async {
    await _saveServers(const [], workspacePath: workspacePath);
    if (workspacePath == null || workspacePath.trim().isEmpty) {
      await _prefs.remove(_legacyStorageKey);
    }
  }

  /// حفظ جميع الخوادم (الاستبدال الكامل)
  Future<void> replaceAllServers(
    List<McpServerConfig> servers, {
    String? workspacePath,
  }) async {
    await _saveServers(servers, workspacePath: workspacePath);
  }

  Future<void> _migrateLegacyPrefsIfNeeded() async {
    if (_legacyMigrationChecked) {
      return;
    }
    _legacyMigrationChecked = true;

    final existingServers = await _settingsStore.readUserMcpServers();
    if (existingServers.isNotEmpty) {
      return;
    }

    final jsonString = _prefs.getString(_legacyStorageKey);
    if (jsonString == null || jsonString.trim().isEmpty) {
      return;
    }

    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is! List) {
        return;
      }

      final servers = decoded
          .whereType<Map>()
          .map((item) => McpServerConfig.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);

      if (servers.isEmpty) {
        return;
      }

      await _settingsStore.saveUserMcpServers(servers);
      await _prefs.remove(_legacyStorageKey);
    } catch (_) {
      // Keep the legacy value intact if migration fails so older clients can still recover it.
    }
  }

  Future<void> _saveServers(
    List<McpServerConfig> servers, {
    String? workspacePath,
  }) async {
    if (workspacePath == null || workspacePath.trim().isEmpty) {
      await _settingsStore.saveUserMcpServers(servers);
      return;
    }
    await _settingsStore.saveWorkspaceMcpServers(workspacePath, servers);
  }
}
