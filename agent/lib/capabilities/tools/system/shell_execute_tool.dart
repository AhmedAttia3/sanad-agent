import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../models/local_tool_spec.dart';
import '../../permissions/permission_manager.dart';
import '../base_tool.dart';
import '../runtime/spec_backed_tool.dart';

class ShellExecuteTool extends SpecBackedTool {
  static const int _maxOutputChars = 50000;
  static const int _maxStreamChars = _maxOutputChars ~/ 2;

  final String workspacePath;
  final PermissionManager? _permissionManager;

  ShellExecuteTool({
    required this.workspacePath,
    PermissionManager? permissionManager,
  }) : _permissionManager = permissionManager;

  @override
  LocalToolSpec get toolSpec => const LocalToolSpec(
    name: 'shell_execute',
    displayName: 'Shell Execute',
    description:
        'Execute a shell command. Starts inside the active workspace; do not "cd" to it.',
    inputSchema: {
      'type': 'object',
      'properties': {
        'command': {'type': 'string'},
        'cwd': {
          'type': 'string',
          'description':
              'Optional subdirectory relative to workspace root. Do not use for root.',
        },
        'timeout_ms': {'type': 'integer'},
      },
      'required': ['command'],
      'additionalProperties': false,
    },
    source: {'type': 'builtin_local', 'id': 'sanad-agent.system'},
    category: 'shell_execution',
    workspaceRequired: true,
    approval: {
      'mode': 'default',
      'sensitive': true,
      'permission_class': 'shell_execution',
    },
    execution: {'target': 'local_runtime', 'timeout_ms': 60000},
    serverName: 'system',
  );

  Future<
    ({String executable, List<String> arguments, Directory? cleanupDirectory})
  >
  _shellCommand(String command) async {
    if (Platform.isWindows) {
      // Passing a quoted command as cmd.exe's /c argument through Dart's
      // Windows process encoder adds literal backslashes around nested quotes.
      // A temporary batch file preserves the command exactly and also gives
      // cmd.exe native PATHEXT lookup for extensionless .bat/.cmd tools.
      final directory = await Directory.systemTemp.createTemp('sanad-shell-');
      final script = File('${directory.path}\\command.cmd');
      await script.writeAsString('@echo off\r\n$command\r\n');
      return (
        executable: Platform.environment['COMSPEC'] ?? 'cmd.exe',
        arguments: ['/d', '/q', '/c', script.path],
        cleanupDirectory: directory,
      );
    }
    // On Linux we launch the command inside a new session/process-group via
    // `setsid`.  This is critical for two reasons:
    //
    // 1. **Process-group isolation:** the child becomes a session leader so
    //    its PGID == its PID.  When the tool kills a timed-out command
    //    (SIGTERM/SIGKILL to the *negative* PID), the signal reaches every
    //    descendant — including backgrounded children — but never the daemon
    //    or its supervisor.
    //
    // 2. **No /dev/tty access:** a new session has no controlling terminal,
    //    so interactive prompts (e.g. `git` asking "Username for ...") fail
    //    immediately instead of blocking forever and holding the tool call.
    //
    // `setsid` (part of util-linux) does NOT double-fork in its default mode:
    // it execs the child in-place, so the PID that Dart sees is the session
    // leader, and stdout/stderr pipes are inherited normally.
    //
    // On macOS `setsid` is not guaranteed, so we fall back to plain `sh`.
    if (Platform.isLinux) {
      return (
        executable: 'setsid',
        arguments: ['sh', '-c', command],
        cleanupDirectory: null,
      );
    }
    return (
      executable: 'sh',
      arguments: ['-c', command],
      cleanupDirectory: null,
    );
  }

  @override
  Future<String> execute(
    Map<String, dynamic> args, {
    ToolContext? context,
  }) async {
    // 1. Enforce permission checking using Daemon's PermissionManager
    if (_permissionManager != null && context != null) {
      await _permissionManager.ensureAuthorized(
        tool: toolSpec,
        arguments: args,
        context: context,
      );
    }

    // 2. Perform safety & parameter checks
    final String cmd = args['command']?.toString() ?? '';
    if (cmd.trim().isEmpty) {
      throw const FormatException('No command provided.');
    }

    final String targetSubPath = args['cwd']?.toString() ?? '';

    // Resolve full working directory path
    String workingDir = workspacePath;
    if (targetSubPath.trim().isNotEmpty) {
      final subDir = Directory(targetSubPath);
      if (subDir.isAbsolute) {
        workingDir = subDir.resolveSymbolicLinksSync();
      } else {
        workingDir = Directory(
          '$workspacePath/$targetSubPath',
        ).resolveSymbolicLinksSync();
      }
    } else {
      workingDir = Directory(workspacePath).resolveSymbolicLinksSync();
    }

    // Path traversal safety check
    final resolvedWorkspaceRoot = Directory(
      workspacePath,
    ).resolveSymbolicLinksSync();
    if (!workingDir.startsWith(resolvedWorkspaceRoot)) {
      throw FileSystemException(
        'Security violation: Target path is outside the workspace root.',
        workingDir,
      );
    }

    // 3. Execution using Process.start to support timeout and clean termination
    final int timeoutMs = args['timeout_ms'] is int
        ? args['timeout_ms'] as int
        : int.tryParse(args['timeout_ms']?.toString() ?? '') ?? 60000;

    final shell = await _shellCommand(cmd);
    Process? process;
    Future<({String text, int totalChars, bool truncated})>? stdoutFuture;
    Future<({String text, int totalChars, bool truncated})>? stderrFuture;
    try {
      process = await Process.start(
        shell.executable,
        shell.arguments,
        workingDirectory: workingDir,
        runInShell: false,
        environment: {
          ...Platform.environment,
          // ── Disable common terminal/askpass prompt paths ──
          // git: never prompt for username/password through the terminal.
          'GIT_TERMINAL_PROMPT': '0',
          'GCM_INTERACTIVE': 'false',
          // ssh: never use an askpass program.
          'SSH_ASKPASS_REQUIRE': 'never',
          if (context?.sessionId.isNotEmpty == true)
            'SANAD_REQUESTER_SESSION_ID': context!.sessionId,
          if (context?.toolCallId?.isNotEmpty == true)
            'SANAD_REQUESTER_TOOL_CALL_ID': context!.toolCallId!,
        },
      );

      // Immediately close the child's stdin. Agent-launched commands are
      // non-interactive; they must never wait for keyboard input. This also
      // prevents a hung child from inheriting an open stdin pipe that blocks
      // the tool call forever (e.g. a command that reads stdin without EOF).
      unawaited(process.stdin.close().catchError((_) {}));

      final localStdout = _collectBoundedOutput(
        process.stdout,
        _maxStreamChars,
      );
      final localStderr = _collectBoundedOutput(
        process.stderr,
        _maxStreamChars,
      );
      stdoutFuture = localStdout;
      stderrFuture = localStderr;

      final results = await Future.wait([
        process.exitCode,
        localStdout,
        localStderr,
      ]).timeout(Duration(milliseconds: timeoutMs));

      final exitCode = results[0] as int;
      final stdoutResult =
          results[1] as ({String text, int totalChars, bool truncated});
      final stderrResult =
          results[2] as ({String text, int totalChars, bool truncated});
      final stdoutStr = _renderBoundedOutput(stdoutResult);
      final stderrStr = _renderBoundedOutput(stderrResult);

      final status = exitCode == 0 ? 'success' : 'error';
      var output = stdoutStr;
      if (stderrStr.isNotEmpty) {
        if (output.isNotEmpty) {
          output += '\n';
        }
        output += 'STDERR:\n$stderrStr';
      }
      if (output.isEmpty && status == 'success') {
        output = 'Command executed successfully (no output).';
      }

      final response = {'isError': exitCode != 0, 'output': output};

      return const JsonEncoder.withIndent('  ').convert(response);
    } on TimeoutException {
      if (process != null) {
        // With `setsid` on Linux, the child PID is also the isolated process
        // group ID. A negative target signals that owned group without
        // reaching the daemon's process group. Use the shell builtin because
        // minimal Linux systems may not ship a standalone `kill` executable.
        if (!Platform.isWindows) {
          try {
            Process.runSync('sh', [
              '-c',
              'kill -TERM -${process.pid} 2>/dev/null || true',
            ]);
          } catch (_) {}
        }
        process.kill(ProcessSignal.sigterm);
        await Future.delayed(const Duration(milliseconds: 500));
        if (!Platform.isWindows) {
          try {
            Process.runSync('sh', [
              '-c',
              'kill -KILL -${process.pid} 2>/dev/null || true',
            ]);
          } catch (_) {}
        }
        process.kill(ProcessSignal.sigkill);
        // Drain residual stdout/stderr so the process fully reaped and no
        // dangling pipe keeps the daemon's event loop alive.
        try {
          await Future.any([
            Future.wait([stdoutFuture!, stderrFuture!]),
            Future.delayed(const Duration(seconds: 2)),
          ]);
        } catch (_) {}
      }
      final response = {
        'isError': true,
        'output': 'Command timed out after $timeoutMs ms.',
      };
      return const JsonEncoder.withIndent('  ').convert(response);
    } catch (e) {
      final response = {
        'isError': true,
        'output': 'Failed to execute command: $e',
      };
      return const JsonEncoder.withIndent('  ').convert(response);
    } finally {
      final cleanupDirectory = shell.cleanupDirectory;
      if (cleanupDirectory != null) {
        try {
          await cleanupDirectory.delete(recursive: true);
        } catch (_) {}
      }
    }
  }

  Future<({String text, int totalChars, bool truncated})> _collectBoundedOutput(
    Stream<List<int>> stream,
    int maxChars,
  ) async {
    final headLimit = (maxChars * 0.4).floor();
    final tailLimit = maxChars - headLimit;
    final head = StringBuffer();
    var tail = '';
    var totalChars = 0;

    await for (final chunk in stream.transform(utf8.decoder)) {
      totalChars += chunk.length;
      var remainingChunk = chunk;
      final availableHead = headLimit - head.length;
      if (availableHead > 0) {
        final take = remainingChunk.length < availableHead
            ? remainingChunk.length
            : availableHead;
        head.write(remainingChunk.substring(0, take));
        remainingChunk = remainingChunk.substring(take);
      }
      if (remainingChunk.isNotEmpty && tailLimit > 0) {
        tail += remainingChunk;
        if (tail.length > tailLimit) {
          tail = tail.substring(tail.length - tailLimit);
        }
      }
    }

    return (
      text: '${head.toString()}$tail',
      totalChars: totalChars,
      truncated: totalChars > maxChars,
    );
  }

  String _renderBoundedOutput(
    ({String text, int totalChars, bool truncated}) result,
  ) {
    if (!result.truncated) {
      return result.text;
    }
    final headChars = (_maxStreamChars * 0.4).floor();
    final tailChars = _maxStreamChars - headChars;
    final head = result.text.substring(0, headChars);
    final tail = result.text.substring(result.text.length - tailChars);
    final omitted = result.totalChars - _maxStreamChars;
    return '$head\n\n... [OUTPUT TRUNCATED: $omitted of ${result.totalChars} characters omitted] ...\n\n$tail';
  }
}
