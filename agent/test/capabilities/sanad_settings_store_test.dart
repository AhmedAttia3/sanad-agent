import 'dart:io';

import 'package:test/test.dart';
import 'package:sanad_agent/capabilities/mcp/sanad_settings_store.dart';

void main() {
  group('SanadSettingsStore', () {
    late Directory tempDir;
    late Directory homeDir;
    late Directory workspaceDir;
    late SanadSettingsStore store;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'sanad-settings-store-test',
      );
      homeDir = Directory('${tempDir.path}/home')..createSync(recursive: true);
      workspaceDir = Directory('${tempDir.path}/workspace')
        ..createSync(recursive: true);
      store = SanadSettingsStore(homeDirectoryPath: homeDir.path);
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test(
      'merges user and workspace MCP configs with workspace precedence',
      () async {
        final userConfig = File('${homeDir.path}/mcp_config.json');
        await userConfig.parent.create(recursive: true);
        await userConfig.writeAsString('''
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["-y", "@modelcontextprotocol/server-filesystem"]
    },
    "shared": {
      "url": "https://user.example.com/mcp"
    }
  }
}
''');

        final workspaceConfig = File(
          '${workspaceDir.path}/.sanad/mcp_config.json',
        );
        await workspaceConfig.parent.create(recursive: true);
        await workspaceConfig.writeAsString('''
{
  "mcpServers": {
    "shared": {
      "url": "https://workspace.example.com/mcp"
    },
    "workspace-only": {
      "command": "python",
      "args": ["server.py"]
    }
  }
}
''');

        final servers = await store.readEffectiveMcpServers(
          workspacePath: workspaceDir.path,
        );
        expect(servers.map((server) => server.name).toSet(), {
          'filesystem',
          'shared',
          'workspace-only',
        });

        final shared = servers.firstWhere((server) => server.name == 'shared');
        expect(shared.serverUrl, equals('https://workspace.example.com/mcp'));
      },
    );
  });
}
