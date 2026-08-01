import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:sanad_agent/capabilities/runtime/workspace_path_resolver.dart';
import 'package:sanad_agent/capabilities/runtime/workspace_tools/file_read_handler.dart';
import 'package:test/test.dart';

void main() {
  group('FileReadHandler Tests', () {
    late Directory tempDir;
    late FileReadHandler handler;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'file-read-handler-test-',
      );
      handler = const FileReadHandler(WorkspacePathResolver());
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    group('Directories', () {
      test(
        'lists files and subdirectories alphabetically with offset and limit',
        () async {
          await File(p.join(tempDir.path, 'zebra.txt')).writeAsString('zebra');
          await File(p.join(tempDir.path, 'apple.txt')).writeAsString('apple');
          await Directory(
            p.join(tempDir.path, 'banana_dir'),
          ).create(recursive: true);
          await Directory(p.join(tempDir.path, '.git')).create(recursive: true);
          await File(
            p.join(tempDir.path, '.git/config'),
          ).writeAsString('gitconfig');

          final rawResult = await handler.execute({'path': '.'}, tempDir.path);
          final result = jsonDecode(rawResult) as Map<String, dynamic>;
          expect(result['type'], 'directory');
          final filePayload = result['file'] as Map<String, dynamic>;
          expect(filePayload['numEntries'], 3);
          expect(filePayload['totalEntries'], 3);

          final content = filePayload['content'] as String;
          expect(content, isNot(contains('.git/')));
          expect(content, isNot(contains('config')));
          expect(content, contains('apple.txt\nbanana_dir/\nzebra.txt'));

          final rawResultLimited = await handler.execute({
            'path': '.',
            'offset': 1,
            'limit': 1,
          }, tempDir.path);
          final resultLimited =
              jsonDecode(rawResultLimited) as Map<String, dynamic>;
          final filePayloadLimited =
              resultLimited['file'] as Map<String, dynamic>;
          expect(filePayloadLimited['numEntries'], 1);
          expect(filePayloadLimited['content'], contains('banana_dir/'));
          expect(filePayloadLimited['content'], contains('offset'));
        },
      );
    });

    group('Binary Sniffing and Line Truncation', () {
      test(
        'rejects binary file with non-printable characters (>30% rule)',
        () async {
          final binFile = File(p.join(tempDir.path, 'binary.bin'));
          final bytes = <int>[
            ...utf8.encode('1234567890'),
            0,
            1,
            2,
            3,
            4,
            5,
            6,
            7,
            8,
            14,
          ];
          await binFile.writeAsBytes(bytes);

          expect(
            () => handler.execute({'path': 'binary.bin'}, tempDir.path),
            throwsA(isA<FileSystemException>()),
          );
        },
      );

      test('truncates very long lines to preserve context tokens', () async {
        final longLineFile = File(p.join(tempDir.path, 'long.txt'));
        final longLine = 'a' * 3000;
        await longLineFile.writeAsString(longLine);

        final rawResult = await handler.execute({
          'path': 'long.txt',
        }, tempDir.path);
        final result = jsonDecode(rawResult) as Map<String, dynamic>;
        final content = result['file']['content'] as String;
        expect(
          content.length,
          2000 + '... (line truncated to 2000 chars)'.length,
        );
        expect(content, endsWith('... (line truncated to 2000 chars)'));
      });

      test(
        'clamps requested pages and returns continuation metadata',
        () async {
          final file = File(p.join(tempDir.path, 'many-lines.txt'));
          await file.writeAsString(
            List.generate(3000, (index) => 'line-$index').join('\n'),
          );

          final rawResult = await handler.execute({
            'path': 'many-lines.txt',
            'limit': 999999,
          }, tempDir.path);
          final result = jsonDecode(rawResult) as Map<String, dynamic>;
          final payload = result['file'] as Map<String, dynamic>;

          expect(payload['numLines'], 2000);
          expect(payload['truncated'], isTrue);
          expect(payload['nextOffset'], 2000);
        },
      );

      test(
        'caps accumulated page characters before encoding the result',
        () async {
          final file = File(p.join(tempDir.path, 'wide-lines.txt'));
          await file.writeAsString(
            List.generate(100, (_) => 'x' * 1000).join('\n'),
          );

          final rawResult = await handler.execute({
            'path': 'wide-lines.txt',
          }, tempDir.path);
          final result = jsonDecode(rawResult) as Map<String, dynamic>;
          final payload = result['file'] as Map<String, dynamic>;

          expect(
            (payload['content'] as String).length,
            lessThanOrEqualTo(50000),
          );
          expect(payload['numLines'], lessThan(100));
          expect(payload['truncated'], isTrue);
          expect(payload['nextOffset'], payload['numLines']);
        },
      );
    });
  });
}
