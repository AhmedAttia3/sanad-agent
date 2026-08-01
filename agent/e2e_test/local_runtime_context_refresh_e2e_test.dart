import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

const _requiredOllamaModel = 'gemma4:e2b';

void main() {
  test(
    'local daemon rebuilds runtime context on every turn for the same thread',
    () async {
      final port = _pickPort();
      final sanadagentLocalDir = Directory.current;
      final ollamaBaseUrl = _normalizeOllamaBaseUrl(
        Platform.environment['LLM_BASE_URL'] ??
            Platform.environment['SANADAGENT_LLM_BASE_URL'] ??
            'http://127.0.0.1:11434',
      );
      await _ensureRequiredOllamaModel(ollamaBaseUrl);

      final sanadHome = await Directory.systemTemp.createTemp(
        'sanad-agent-context-refresh-e2e-home',
      );
      final workspaceDir = Directory('${sanadHome.path}/workspace')
        ..createSync(recursive: true);
      final agentsFile = File('${workspaceDir.path}/AGENTS.md');

      addTearDown(() async {
        if (sanadHome.existsSync()) {
          await sanadHome.delete(recursive: true);
        }
      });

      const firstMarker = 'ALPHA_CONTEXT_MARKER_741';
      const secondMarker = 'BETA_CONTEXT_MARKER_982';
      await agentsFile.writeAsString('''
Runtime context refresh test.
CURRENT_RUNTIME_MARKER=$firstMarker
''');

      final daemon = await _startDaemon(
        sanadagentLocalDir: sanadagentLocalDir,
        sanadHome: sanadHome,
        port: port,
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
          'context-refresh-e2e-${DateTime.now().millisecondsSinceEpoch}';

      final firstAnswer = await _sendThinkAndAwaitFinalAnswer(
        socket: socket,
        frames: frames,
        sessionId: sessionId,
        workspacePath: workspaceDir.path,
        requestIdPrefix: 'ctx-refresh-1',
      );
      expect(firstAnswer, contains(firstMarker));

      await agentsFile.writeAsString('''
Runtime context refresh test.
CURRENT_RUNTIME_MARKER=$secondMarker
''');

      final secondAnswer = await _sendThinkAndAwaitFinalAnswer(
        socket: socket,
        frames: frames,
        sessionId: sessionId,
        workspacePath: workspaceDir.path,
        requestIdPrefix: 'ctx-refresh-2',
      );

      expect(secondAnswer, contains(secondMarker));
      expect(secondAnswer, isNot(contains(firstMarker)));

      await frames.cancel();
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<String> _sendThinkAndAwaitFinalAnswer({
  required WebSocket socket,
  required StreamIterator<dynamic> frames,
  required String sessionId,
  required String workspacePath,
  required String requestIdPrefix,
}) async {
  final requestId = '$requestIdPrefix-${DateTime.now().millisecondsSinceEpoch}';
  socket.add(
    jsonEncode({
      'type': 'execute_command',
      'command': 'think',
      'payload': {
        'request_id': requestId,
        'session_id': sessionId,
        'workspace_id': workspacePath,
        'model': 'ollama/$_requiredOllamaModel',
        'message':
            'Read the current runtime context and reply with exactly the value of CURRENT_RUNTIME_MARKER. '
            'Ignore previous conversation answers and use the latest runtime context only. '
            'Output the marker only with no extra words or punctuation.',
      },
    }),
  );

  final deadline = DateTime.now().add(const Duration(seconds: 90));
  while (DateTime.now().isBefore(deadline)) {
    if (!await frames.moveNext()) {
      break;
    }

    final frame = jsonDecode(frames.current as String) as Map<String, dynamic>;
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

    if (frame['event'] == 'final_answer') {
      final content = payload['content']?.toString().trim() ?? '';
      if (content.isNotEmpty) {
        return content;
      }
    }
  }

  throw StateError('Timed out waiting for final_answer for session $sessionId');
}

int _pickPort() {
  const basePort = 58620;
  return basePort + (DateTime.now().millisecondsSinceEpoch % 200);
}

Future<Process> _startDaemon({
  required Directory sanadagentLocalDir,
  required Directory sanadHome,
  required int port,
}) async {
  final environment = <String, String>{
    ...Platform.environment,
    'SANAD_HOME': sanadHome.path,
    'ENABLE_GATEWAY': 'false',
    'ENABLE_LOCAL_GATEWAY': 'true',
    'LOCAL_GATEWAY_PORT': '$port',
    'LLM_BASE_URL': 'http://127.0.0.1:11434',
    'LLM_MODEL': _requiredOllamaModel,
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

Future<void> _ensureRequiredOllamaModel(String baseUrl) async {
  final client = HttpClient();
  try {
    final request = await client.getUrl(Uri.parse('$baseUrl/api/tags'));
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('Ollama tags request failed: $body');
    }

    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final installedNames = (decoded['models'] as List<dynamic>? ?? const [])
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .map((entry) => entry['name']?.toString() ?? '')
        .where((name) => name.isNotEmpty)
        .toList(growable: false);

    if (!installedNames.contains(_requiredOllamaModel)) {
      throw StateError(
        'Required Ollama model $_requiredOllamaModel is not installed. '
        'Installed models: ${installedNames.join(', ')}',
      );
    }
  } finally {
    client.close(force: true);
  }
}
