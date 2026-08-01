import 'dart:convert';
import 'dart:io';
import 'package:path/path.dart' as p;

class WorkspaceToolsUtils {
  static String encode(Map<String, dynamic> payload) {
    return const JsonEncoder.withIndent('  ').convert(payload);
  }

  static int? asPositiveInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return (parsed == null || parsed < 1) ? null : parsed;
  }

  static int? asNonNegativeInt(dynamic value) {
    final parsed = value is int ? value : int.tryParse(value?.toString() ?? '');
    return (parsed == null || parsed < 0) ? null : parsed;
  }

  static Future<bool> looksBinary(File file) async {
    final stream = file.openRead(0, 4096);
    final chunks = await stream.take(1).toList();
    if (chunks.isEmpty) return false;
    final bytes = chunks.first;
    var nonPrintableCount = 0;
    for (final byte in bytes) {
      if (byte == 0) return true;
      if (byte < 9 || (byte > 13 && byte < 32)) {
        nonPrintableCount++;
      }
    }
    return nonPrintableCount / bytes.length > 0.3;
  }

  static Stream<File> listWorkspaceFiles(String dirPath) async* {
    final dir = Directory(dirPath);
    List<FileSystemEntity> entities;
    try {
      entities = await dir.list(followLinks: false).toList();
    } catch (_) {
      return;
    }
    for (final entity in entities) {
      final name = p.basename(entity.path);
      if (entity is Directory) {
        if (const {
          '.git',
          'node_modules',
          '.dart_tool',
          '.fvm',
          'build',
          '.gradle',
          '.idea',
          'ios',
          'android',
          'venv',
          '.venv',
          '__pycache__',
          '.pytest_cache',
          'site-packages',
          '.next',
          '.nuxt',
          'dist',
          'target',
        }.contains(name)) {
          continue;
        }
        yield* listWorkspaceFiles(entity.path);
      } else if (entity is File) {
        yield entity;
      }
    }
  }

  static RegExp globToRegExp(String pattern) {
    final buffer = StringBuffer('^');
    var i = 0;
    while (i < pattern.length) {
      final char = pattern[i];
      if (char == '*') {
        final isDouble = i + 1 < pattern.length && pattern[i + 1] == '*';
        if (isDouble) {
          buffer.write('.*');
          i += 2;
          continue;
        }
        buffer.write('[^/]*');
      } else if (char == '?') {
        buffer.write('.');
      } else if ('.+()|^\$[]{}'.contains(char)) {
        buffer.write('\\$char');
      } else {
        buffer.write(char);
      }
      i++;
    }
    buffer.write(r'$');
    return RegExp(buffer.toString());
  }

  static List<String> expandBraces(String pattern) {
    final open = pattern.indexOf('{');
    if (open == -1) return [pattern];
    final close = pattern.indexOf('}', open);
    if (close == -1) return [pattern];

    final prefix = pattern.substring(0, open);
    final suffix = pattern.substring(close + 1);
    final alternatives = pattern.substring(open + 1, close).split(',');

    final results = <String>[];
    for (final alternative in alternatives) {
      results.addAll(expandBraces('$prefix$alternative$suffix'));
    }
    return results;
  }
}
