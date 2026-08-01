import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sanad_agent/capabilities/runtime/workspace_path_resolver.dart';
import 'package:sanad_agent/capabilities/runtime/workspace_tools/search_glob_handler.dart';
import 'package:sanad_agent/capabilities/runtime/workspace_tools/search_grep_handler.dart';
import 'package:test/test.dart';

void main() {
  group('Search Handlers Tests', () {
    late Directory tempDir;
    late SearchGlobHandler globHandler;
    late SearchGrepHandler grepHandler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('search-handlers-test-');
      final pathResolver = const WorkspacePathResolver();
      globHandler = SearchGlobHandler(pathResolver);
      grepHandler = SearchGrepHandler(pathResolver);
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test(
      'ignores system folders (.git, node_modules, etc) during recursive scan',
      () async {
        await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
        await Directory(
          p.join(tempDir.path, 'node_modules/dep'),
        ).create(recursive: true);
        await Directory(p.join(tempDir.path, '.git')).create(recursive: true);

        await File(
          p.join(tempDir.path, 'lib/a.dart'),
        ).writeAsString('class Sanad {}');
        await File(
          p.join(tempDir.path, 'node_modules/dep/a.dart'),
        ).writeAsString('class Sanad {}');
        await File(
          p.join(tempDir.path, '.git/a.dart'),
        ).writeAsString('class Sanad {}');

        final globRaw = await globHandler.execute({
          'pattern': '**/a.dart',
        }, tempDir.path);
        final globResult = jsonDecode(globRaw) as Map<String, dynamic>;
        expect(globResult['filenames'], ['lib/a.dart']);

        final grepRaw = await grepHandler.execute({
          'pattern': 'class Sanad',
        }, tempDir.path);
        final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;
        expect(grepResult['filenames'], ['lib/a.dart']);
      },
    );

    test('skips generated dependency trees during recursive scan', () async {
      final included = Directory(p.join(tempDir.path, 'lib'))
        ..createSync(recursive: true);
      final excluded = [
        '.venv/lib',
        'venv/lib',
        'site-packages/pkg',
        '.next/cache',
        'dist/assets',
        'target/generated',
      ];
      await File(p.join(included.path, 'included.txt')).writeAsString('needle');
      for (final path in excluded) {
        final directory = Directory(p.join(tempDir.path, path))
          ..createSync(recursive: true);
        await File(
          p.join(directory.path, 'excluded.txt'),
        ).writeAsString('needle');
      }

      final raw = await grepHandler.execute({
        'pattern': 'needle',
      }, tempDir.path);
      final result = jsonDecode(raw) as Map<String, dynamic>;

      expect(result['filenames'], ['lib/included.txt']);
      expect(result['numLines'], 1);
    });

    test('skips non-UTF-8 files without failing the search', () async {
      await File(p.join(tempDir.path, 'valid.txt')).writeAsString('needle');
      await File(
        p.join(tempDir.path, 'invalid.txt'),
      ).writeAsBytes([...utf8.encode('mostly printable '), 0x80]);

      final raw = await grepHandler.execute({
        'pattern': 'needle',
      }, tempDir.path);
      final result = jsonDecode(raw) as Map<String, dynamic>;

      expect(result['filenames'], ['valid.txt']);
      expect(result['numLines'], 1);
    });

    test('normalizes grep patterns with spaces and duplicate pipes', () async {
      await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
      await File(p.join(tempDir.path, 'lib/test.dart')).writeAsString(
        'class SessionRunOrchestrator {}\n'
        'class RuntimeRecoveryService {}\n'
        'class AgentStateDatabase {}\n'
        'class SessionManager {}\n',
      );

      // Test with spaces around pipes and duplicate pipes
      final grepRaw = await grepHandler.execute({
        'pattern':
            'SessionRunOrchestrator| RuntimeRecoveryService|AgentStateDatabase||SessionManager',
        'line_numbers': true,
      }, tempDir.path);
      final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

      expect(grepResult['numFiles'], 1);
      expect(grepResult['filenames'], ['lib/test.dart']);
      expect(grepResult['numLines'], 4); // All 4 classes should match
      expect(grepResult['content'], isNotEmpty);
    });

    test(
      'converts grep BRE alternation (backslash-pipe) to Dart RegExp alternation',
      () async {
        // grep BRE uses \| for alternation, but Dart RegExp uses bare |.
        // A user typing the pattern from a grep command should get matches.
        await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
        await File(p.join(tempDir.path, 'lib/account.py')).writeAsString(
          '    reset_at: Optional[datetime] = None\n'
          '        if window.reset_at:\n'
          '        return normalized + "/wham/usage"\n'
          '    for key, label in (("primary_window", "Session"), ("secondary_window", "Weekly")):\n'
          '        ("five_hour", "Current session"),\n'
          '    unrelated_line = 42\n',
        );

        final grepRaw = await grepHandler.execute({
          'pattern':
              r'wham/usage\|primary_window\|secondary_window\|reset_at\|five_hour',
          'line_numbers': true,
          'case_insensitive': true,
        }, tempDir.path);
        final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

        expect(grepResult['numFiles'], 1);
        expect(grepResult['filenames'], ['lib/account.py']);
        // 5 matching lines (reset_at appears twice, wham/usage once,
        // primary_window+secondary_window once, five_hour once) = 5
        expect(grepResult['numLines'], 5);
        expect(grepResult['content'], isNotEmpty);
      },
    );

    test(
      'grep pattern with various whitespace and pipe combinations',
      () async {
        await Directory(p.join(tempDir.path, 'src')).create(recursive: true);
        await File(p.join(tempDir.path, 'src/code.dart')).writeAsString(
          'final pattern1 = "test";\n'
          'final pattern2 = "test";\n'
          'final pattern3 = "test";\n',
        );

        // Multiple variations of whitespace
        final patterns = [
          'pattern1| pattern2 | pattern3', // spaces around pipes
          'pattern1||pattern2||pattern3', // duplicate pipes
          ' pattern1 | pattern2 | pattern3 ', // leading/trailing spaces
        ];

        for (final pattern in patterns) {
          final grepRaw = await grepHandler.execute({
            'pattern': pattern,
          }, tempDir.path);
          final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;
          expect(
            grepResult['numLines'],
            3,
            reason: 'Pattern "$pattern" should match all 3 lines',
          );
        }
      },
    );

    test(
      'falls back to literal search when pattern is a malformed regex (e.g. has unterminated braces)',
      () async {
        await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
        await File(p.join(tempDir.path, 'lib/test.dart')).writeAsString(
          'class ProviderInstance({\n'
          '  final String id;\n'
          ')\n',
        );

        final grepRaw = await grepHandler.execute({
          'pattern': 'ProviderInstance({',
        }, tempDir.path);
        final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

        expect(grepResult['numFiles'], 1);
        expect(grepResult['filenames'], ['lib/test.dart']);
        expect(grepResult['numLines'], 1);
        expect(grepResult['content'][0], contains('class ProviderInstance({'));
      },
    );

    test('grep glob matches nested file basenames', () async {
      await Directory(
        p.join(tempDir.path, 'lib/nested'),
      ).create(recursive: true);
      await File(
        p.join(tempDir.path, 'lib/nested/match.dart'),
      ).writeAsString('class NestedMatch {}\n');
      await File(
        p.join(tempDir.path, 'lib/nested/skip.txt'),
      ).writeAsString('class NestedMatch {}\n');

      final grepRaw = await grepHandler.execute({
        'pattern': 'NestedMatch',
        'glob': '*.dart',
      }, tempDir.path);
      final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

      expect(grepResult['filenames'], ['lib/nested/match.dart']);
      expect(grepResult['numLines'], 1);
    });

    test('grep glob expands brace alternatives', () async {
      await Directory(p.join(tempDir.path, 'src')).create(recursive: true);
      await File(
        p.join(tempDir.path, 'src/match.dart'),
      ).writeAsString('sharedMarker\n');
      await File(
        p.join(tempDir.path, 'src/match.ts'),
      ).writeAsString('sharedMarker\n');
      await File(
        p.join(tempDir.path, 'src/skip.py'),
      ).writeAsString('sharedMarker\n');

      final grepRaw = await grepHandler.execute({
        'pattern': 'sharedMarker',
        'glob': '*.{dart,ts}',
      }, tempDir.path);
      final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

      expect(grepResult['filenames'], ['src/match.dart', 'src/match.ts']);
      expect(grepResult['numLines'], 2);
    });

    test(
      'searches a specific single file when a file path is provided as the path parameter',
      () async {
        await Directory(p.join(tempDir.path, 'lib')).create(recursive: true);
        await File(p.join(tempDir.path, 'lib/test.dart')).writeAsString(
          'class SessionRunOrchestrator {}\n'
          'class OtherClass {}\n',
        );

        final grepRaw = await grepHandler.execute({
          'pattern': 'SessionRunOrchestrator',
          'path': 'lib/test.dart',
        }, tempDir.path);
        final grepResult = jsonDecode(grepRaw) as Map<String, dynamic>;

        expect(grepResult['numFiles'], 1);
        expect(grepResult['filenames'], ['lib/test.dart']);
        expect(grepResult['numLines'], 1);
        expect(
          grepResult['content'][0],
          contains('class SessionRunOrchestrator'),
        );
      },
    );

    test('clamps head_limit and truncates pathological long lines', () async {
      final file = File(p.join(tempDir.path, 'large.txt'));
      await file.writeAsString(
        List.generate(150, (index) => 'match-$index ${'x' * 3000}').join('\n'),
      );

      final grepRaw = await grepHandler.execute({
        'pattern': 'match-',
        'head_limit': 999999,
      }, tempDir.path);
      final result = jsonDecode(grepRaw) as Map<String, dynamic>;
      final content = (result['content'] as List).cast<String>();

      expect(content.length, lessThanOrEqualTo(100));
      expect(content.join().length, lessThanOrEqualTo(50000));
      expect(content.first, contains('line truncated to 2000 chars'));
      expect(result['truncated'], isTrue);
    });

    test('clamps caller-provided context lines', () async {
      final file = File(p.join(tempDir.path, 'context.txt'));
      await file.writeAsString(
        List.generate(
          100,
          (index) => index == 50 ? 'needle' : 'line-$index',
        ).join('\n'),
      );

      final grepRaw = await grepHandler.execute({
        'pattern': 'needle',
        'context': 999999,
      }, tempDir.path);
      final result = jsonDecode(grepRaw) as Map<String, dynamic>;

      expect(result['numLines'], 41);
    });
  });
}
