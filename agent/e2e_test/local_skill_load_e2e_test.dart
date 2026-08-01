import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _requiredOllamaModel = 'gemma4:e2b';

void main() {
  test(
    'local daemon executes skill_load through the real think path',
    () async {
      final port = _pickPort();
      final sanadagentLocalDir = Directory.current;
      final ollamaBaseUrl = _normalizeOllamaBaseUrl(
        Platform.environment['LLM_BASE_URL'] ??
            Platform.environment['SANADAGENT_LLM_BASE_URL'] ??
            'http://127.0.0.1:11434',
      );
      final configuredModel = await _resolveInstalledOllamaModel(ollamaBaseUrl);
      final sanadHome = await Directory.systemTemp.createTemp(
        'sanad-agent-skill-e2e-home',
      );
      final workspaceDir = Directory('${sanadHome.path}/workspace')
        ..createSync(recursive: true);

      addTearDown(() async {
        if (sanadHome.existsSync()) {
          await sanadHome.delete(recursive: true);
        }
      });

      await File(
        '${workspaceDir.path}/AGENTS.md',
      ).writeAsString('Workspace owned by the skill load e2e test.');
      await Directory(
        '${workspaceDir.path}/.sanad/skills/review',
      ).create(recursive: true);
      await File(
        '${workspaceDir.path}/.sanad/skills/review/SKILL.md',
      ).writeAsString('''---
name: review
description: Review the workspace and report findings.
---
Use the review skill for workspace audits.
''');

      final daemon = await _startDaemon(
        sanadagentLocalDir: sanadagentLocalDir,
        sanadHome: sanadHome,
        port: port,
        configuredModel: configuredModel,
        configuredBaseUrl: ollamaBaseUrl,
      );
      addTearDown(() async {
        daemon.kill(ProcessSignal.sigterm);
        await daemon.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            daemon.kill(ProcessSignal.sigkill);
            return -1;
          },
        );
      });

      await _waitForHealth(port);

      final socket = await WebSocket.connect('ws://127.0.0.1:$port/ws');
      addTearDown(() async {
        await socket.close();
      });

      final frames = StreamIterator(socket);
      expect(await frames.moveNext(), isTrue);
      final registerSuccess =
          jsonDecode(frames.current as String) as Map<String, dynamic>;
      expect(registerSuccess['type'], equals('register_success'));

      final sessionId =
          'skill-load-e2e-${DateTime.now().millisecondsSinceEpoch}';
      final requestId =
          'req-skill-load-${DateTime.now().millisecondsSinceEpoch}';

      socket.add(
        jsonEncode({
          'type': 'execute_command',
          'command': 'think',
          'payload': {
            'request_id': requestId,
            'session_id': sessionId,
            'workspace_id': workspaceDir.path,
            'model': 'ollama/$configuredModel',
            'message':
                'You must call the tool named skill_load exactly once as your first action with skill="review" and args="--focus docs". '
                'Do not answer from memory and do not skip the tool call. '
                'After the tool returns, answer with exactly OK.',
          },
        }),
      );

      Map<String, dynamic>? toolUseFrame;
      Map<String, dynamic>? toolResultFrame;
      Map<String, dynamic>? finalAnswerFrame;
      final deadline = DateTime.now().add(const Duration(seconds: 90));

      while (DateTime.now().isBefore(deadline)) {
        if (!await frames.moveNext()) {
          break;
        }

        final frame =
            jsonDecode(frames.current as String) as Map<String, dynamic>;
        if (frame['type'] != 'device_event') {
          continue;
        }

        final payload = frame['payload'] is Map
            ? Map<String, dynamic>.from(frame['payload'] as Map)
            : <String, dynamic>{};
        final eventSessionId =
            frame['session_id'] as String? ?? payload['session_id'] as String?;
        if (eventSessionId != sessionId) {
          continue;
        }

        final eventType = frame['event'] as String?;
        if (eventType == 'tool_use' && payload['tool'] == 'skill_load') {
          toolUseFrame = frame;
        } else if (eventType == 'tool_result' &&
            payload['tool'] == 'skill_load') {
          toolResultFrame = frame;
        } else if (eventType == 'final_answer') {
          finalAnswerFrame = frame;
          if ((payload['status']?.toString() ?? 'done') == 'done') {
            break;
          }
        }
      }

      expect(
        toolUseFrame,
        isNotNull,
        reason: 'skill_load tool_use was never observed.',
      );
      expect(
        toolResultFrame,
        isNotNull,
        reason: 'skill_load tool_result was never observed.',
      );
      expect(
        finalAnswerFrame,
        isNotNull,
        reason: 'final_answer was never observed.',
      );

      final toolUsePayload = Map<String, dynamic>.from(
        toolUseFrame!['payload'] as Map,
      );
      final toolUseInput = toolUsePayload['input']?.toString() ?? '';
      expect(toolUseInput, contains('"skill":"review"'));

      final toolResultPayload = Map<String, dynamic>.from(
        toolResultFrame!['payload'] as Map,
      );
      final toolOutput = toolResultPayload['output']?.toString() ?? '';
      expect(toolOutput, contains('"skill": "review"'));
      expect(toolOutput, contains('"args": "--focus docs"'));
      expect(
        toolOutput,
        contains('Use the review skill for workspace audits.'),
      );
      expect(toolResultPayload['isError'], isFalse);

      final finalPayload = Map<String, dynamic>.from(
        finalAnswerFrame!['payload'] as Map,
      );
      expect(finalPayload['content']?.toString().trim(), isNotEmpty);

      await frames.cancel();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

int _pickPort() {
  const basePort = 58420;
  return basePort + (DateTime.now().millisecondsSinceEpoch % 200);
}

Future<Process> _startDaemon({
  required Directory sanadagentLocalDir,
  required Directory sanadHome,
  required int port,
  required String configuredModel,
  required String configuredBaseUrl,
}) async {
  final environment = <String, String>{
    ...Platform.environment,
    'SANAD_HOME': sanadHome.path,
    'ENABLE_GATEWAY': 'false',
    'ENABLE_LOCAL_GATEWAY': 'true',
    'LOCAL_GATEWAY_PORT': '$port',
    'LLM_BASE_URL': configuredBaseUrl,
    'LLM_MODEL': configuredModel,
  };

  final process = await Process.start(
    Platform.resolvedExecutable,
    ['bin/daemon.dart'],
    workingDirectory: sanadagentLocalDir.path,
    environment: environment,
  );

  unawaited(
    process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stdout.writeln('[daemon] $line'))
        .asFuture<void>(),
  );
  unawaited(
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen((line) => stderr.writeln('[daemon] $line'))
        .asFuture<void>(),
  );

  return process;
}

Future<void> _waitForHealth(int port) async {
  final client = HttpClient();
  final deadline = DateTime.now().add(const Duration(seconds: 20));
  Object? lastError;

  try {
    while (DateTime.now().isBefore(deadline)) {
      try {
        final request = await client.getUrl(
          Uri.parse('http://127.0.0.1:$port/health'),
        );
        final response = await request.close();
        final body = await response.transform(utf8.decoder).join();
        if (response.statusCode == 200) {
          final decoded = jsonDecode(body) as Map<String, dynamic>;
          if (decoded['status'] == 'ok') {
            return;
          }
        }
        lastError = StateError('Unexpected health response: $body');
      } catch (error) {
        lastError = error;
      }

      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
  } finally {
    client.close(force: true);
  }

  throw StateError(
    'Local daemon health endpoint did not become ready: $lastError',
  );
}

String _normalizeOllamaBaseUrl(String raw) {
  final trimmed = raw.trim();
  if (trimmed.endsWith('/v1')) {
    return trimmed.substring(0, trimmed.length - 3);
  }
  return trimmed;
}

Future<String> _resolveInstalledOllamaModel(String baseUrl) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$baseUrl/api/tags'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('Ollama tags request failed: $body');
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final rawModels = (decoded['models'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .toList(growable: false);
    if (rawModels.isEmpty) {
      throw StateError('No Ollama models are installed.');
    }

    final installedNames = rawModels
        .map((entry) => entry['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);
    if (!installedNames.contains(_requiredOllamaModel)) {
      throw StateError(
        'Required Ollama model $_requiredOllamaModel is not installed. '
        'Installed models: ${installedNames.join(', ')}',
      );
    }

    return _requiredOllamaModel;
  } finally {
    client.close(force: true);
  }
}
