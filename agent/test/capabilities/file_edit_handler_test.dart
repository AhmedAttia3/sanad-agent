import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sanad_agent/capabilities/runtime/workspace_path_resolver.dart';
import 'package:sanad_agent/capabilities/runtime/workspace_tools/file_edit_handler.dart';
import 'package:test/test.dart';

void main() {
  group('FileEditHandler Tests', () {
    late Directory tempDir;
    late FileEditHandler handler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'file-edit-handler-test-',
      );
      handler = const FileEditHandler(WorkspacePathResolver());
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Smart Replacers', () {
      test('handles simple exact match and replace', () async {
        final testFile = File(p.join(tempDir.path, 'edit_test.txt'));
        await testFile.writeAsString('hello world');

        final editRaw = await handler.execute({
          'path': 'edit_test.txt',
          'old_string': 'world',
          'new_string': 'sanad',
        }, tempDir.path);
        final edited = jsonDecode(editRaw) as Map<String, dynamic>;
        expect(edited['numReplacements'], 1);
        expect(await testFile.readAsString(), 'hello sanad');
      });

      test(
        'handles line trimmed replacement (ignoring leading/trailing line spacing)',
        () async {
          final testFile = File(p.join(tempDir.path, 'edit_trimmed.txt'));
          await testFile.writeAsString(
            '  line one  \n  line two  \nline three',
          );

          await handler.execute({
            'path': 'edit_trimmed.txt',
            'old_string': 'line one\nline two',
            'new_string': 'line 1\nline 2',
          }, tempDir.path);
          expect(await testFile.readAsString(), 'line 1\nline 2\nline three');
        },
      );

      test('handles whitespace normalized replacement', () async {
        final testFile = File(p.join(tempDir.path, 'edit_whitespace.txt'));
        await testFile.writeAsString('hello      beautiful   world');

        await handler.execute({
          'path': 'edit_whitespace.txt',
          'old_string': 'hello beautiful world',
          'new_string': 'hello world',
        }, tempDir.path);
        expect(await testFile.readAsString(), 'hello world');
      });

      test('handles BlockAnchorReplacer using Levenshtein distance', () async {
        final testFile = File(p.join(tempDir.path, 'edit_anchors.txt'));
        await testFile.writeAsString(
          'START_HEADER\nsome middle text that LLM might slightly misspell\nEND_FOOTER',
        );

        await handler.execute({
          'path': 'edit_anchors.txt',
          'old_string':
              'START_HEADER\nsome middle text that LLM misspelled slightly\nEND_FOOTER',
          'new_string': 'START_HEADER\nperfect middle text\nEND_FOOTER',
        }, tempDir.path);
        expect(
          await testFile.readAsString(),
          'START_HEADER\nperfect middle text\nEND_FOOTER',
        );
      });

      test(
        'handles Windows CRLF and Unix LF normalization automatically',
        () async {
          final testFile = File(p.join(tempDir.path, 'edit_crlf.txt'));
          await testFile.writeAsString('line1\r\nline2\r\nline3\r\n');

          await handler.execute({
            'path': 'edit_crlf.txt',
            'old_string': 'line2\nline3',
            'new_string': 'updated2\nupdated3',
          }, tempDir.path);
          expect(
            await testFile.readAsString(),
            'line1\r\nupdated2\r\nupdated3\r\n',
          );
        },
      );

      test(
        'throws StateError when old_string is not found (avoids Infinity or NaN toInt)',
        () async {
          final testFile = File(p.join(tempDir.path, 'not_found_test.txt'));
          await testFile.writeAsString('some content');

          expect(
            () => handler.execute({
              'path': 'not_found_test.txt',
              'old_string': 'nonexistent_string',
              'new_string': 'replacement',
            }, tempDir.path),
            throwsA(
              isA<StateError>().having(
                (e) => e.message,
                'message',
                contains('old_string was not found in the target file'),
              ),
            ),
          );
        },
      );
    });
  });
}
