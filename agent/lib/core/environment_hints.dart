import 'dart:io';

class EnvironmentHints {
  static const String windowsCommandShellHint =
      "Shell: on this Windows host your `terminal` tool runs commands through "
      "the native Windows command interpreter (`cmd.exe`), NOT PowerShell or "
      "bash. Use cmd syntax (`dir`, `%USERPROFILE%`, `&&`, `|`) and native "
      "Windows paths such as `C:\\Users\\<user>\\...`. PowerShell builtins "
      "(`Get-ChildItem`, `\$env:FOO`, `Select-String`) and POSIX-only commands "
      "(`ls`, `export`, `source`) will not work unless their executables are "
      "installed and available in PATH.";

  static const String wslEnvironmentHint =
      "You are running inside WSL (Windows Subsystem for Linux). "
      "The Windows host filesystem is mounted under /mnt/ — "
      "/mnt/c/ is the C: drive, /mnt/d/ is D:, etc. "
      "The user's Windows files are typically at "
      "/mnt/c/Users/<username>/Desktop/, Documents/, Downloads/, etc. "
      "When the user references Windows paths or desktop files, translate "
      "to the /mnt/c/ equivalent. You can list /mnt/c/Users/ to discover "
      "the Windows username if needed.";

  /// Returns environment-specific guidance for the system prompt.
  static String build() {
    final hints = <String>[];
    final hostLines = <String>[];

    final isWsl = detectWsl();

    if (isWsl) {
      hostLines.add('Host: WSL (Windows Subsystem for Linux)');
    } else if (Platform.isWindows) {
      hostLines.add('Host: Windows (${Platform.operatingSystemVersion})');
    } else if (Platform.isMacOS) {
      hostLines.add('Host: macOS (${Platform.operatingSystemVersion})');
    } else if (Platform.isLinux) {
      hostLines.add('Host: Linux (${Platform.operatingSystemVersion})');
    } else {
      hostLines.add(
        'Host: ${Platform.operatingSystem} (${Platform.operatingSystemVersion})',
      );
    }

    final home = Platform.isWindows
        ? Platform.environment['USERPROFILE']
        : Platform.environment['HOME'];
    if (home != null && home.isNotEmpty) {
      hostLines.add('User home directory: $home');
    }

    if (Platform.isWindows && !isWsl) {
      hostLines.add(
        "Note: on Windows, the machine hostname (e.g. from `hostname` "
        "or uname) is NOT the username. Use the 'User home directory' "
        "above to construct paths under C:\\Users\\<user>\\, never the "
        "hostname.",
      );
    }

    if (hostLines.isNotEmpty) {
      hints.add(hostLines.join('\n'));
    }

    // Native Windows terminal commands run through cmd.exe, not PowerShell.
    if (Platform.isWindows && !isWsl) {
      hints.add(windowsCommandShellHint);
    }

    if (isWsl) {
      hints.add(wslEnvironmentHint);
    }

    return hints.join('\n\n');
  }

  /// Detects if the current environment is running inside WSL.
  static bool detectWsl() {
    if (!Platform.isLinux) return false;
    if (Platform.environment.containsKey('WSL_DISTRO_NAME') ||
        Platform.environment.containsKey('WSL_INTEROP')) {
      return true;
    }
    try {
      final file = File('/proc/version');
      if (file.existsSync()) {
        final content = file.readAsStringSync().toLowerCase();
        return content.contains('microsoft') || content.contains('wsl');
      }
    } catch (_) {}
    return false;
  }
}
