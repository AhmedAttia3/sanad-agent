import 'dart:convert';
import 'dart:io';

import 'package:sanad_release_contract/release_contract.dart';

Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) _usage();
  final command = arguments.first;
  final options = _options(arguments.skip(1));
  final repoRoot = Directory(options['repo-root'] ?? '..').absolute;
  try {
    switch (command) {
      case 'validate-contract':
        await _validateContract(repoRoot, tag: options['tag']);
        return;
      case 'generate-manifest':
        await _generateManifest(
          repoRoot,
          artifactsDirectory: _required(options, 'artifacts'),
          commit: _required(options, 'commit'),
          output: _required(options, 'output'),
        );
        return;
      case 'verify-manifest':
        await _verifyManifest(
          File(_required(options, 'manifest')),
          artifactsDirectory: options['artifacts'],
        );
        return;
      case 'generate-appcast':
        await _generateAppcast(
          File(_required(options, 'manifest')),
          File(_required(options, 'output')),
          publishedAt: options['published-at'],
        );
        return;
      default:
        _usage('Unknown command: $command');
    }
  } on FormatException catch (error) {
    stderr.writeln('Release contract error: ${error.message}');
    exitCode = 2;
  }
}

Future<void> _validateContract(Directory root, {String? tag}) async {
  final contract = await _readContract(root);
  final agentVersion = _pubspecVersion(
    File('${root.path}/agent/pubspec.yaml'),
  ).split('+').first;
  final clientParts = _pubspecVersion(
    File('${root.path}/client/pubspec.yaml'),
  ).split('+');
  final clientVersion = clientParts.first;
  final clientBuild = int.tryParse(
    clientParts.length > 1 ? clientParts[1] : '',
  );
  final version = contract['version']?.toString();
  if (version == null || version.isEmpty) {
    throw const FormatException('Contract version is required.');
  }
  final build = contract['build_number'] as int?;
  final expectedTag = contract['tag']?.toString();
  if (contract['repository'] != sanadReleaseRepository) {
    throw FormatException(
      'Contract repository must be $sanadReleaseRepository.',
    );
  }
  if (agentVersion != version || clientVersion != version) {
    throw FormatException(
      'Agent ($agentVersion), client ($clientVersion), and contract ($version) versions must match.',
    );
  }
  if (clientBuild != build) {
    throw FormatException(
      'Client build ($clientBuild) must match contract build ($build).',
    );
  }
  if (expectedTag != 'v$version') {
    throw FormatException('Contract tag must be v$version.');
  }
  if (tag != null && tag != expectedTag) {
    throw FormatException('Workflow tag $tag does not match $expectedTag.');
  }
  final artifacts = contract['artifacts'];
  if (artifacts is! List || artifacts.isEmpty) {
    throw const FormatException('Contract must define artifacts.');
  }
  final names = <String>{};
  for (final raw in artifacts) {
    final artifact = Map<String, dynamic>.from(raw as Map);
    final filename = artifact['filename']?.toString() ?? '';
    if (!filename.contains(version) || !names.add(filename)) {
      throw FormatException('Invalid or duplicate filename: $filename');
    }
  }
  stdout.writeln('Release contract valid: $expectedTag+$build');
}

Future<void> _generateManifest(
  Directory root, {
  required String artifactsDirectory,
  required String commit,
  required String output,
}) async {
  await _validateContract(root);
  if (!RegExp(r'^[0-9a-f]{7,40}$').hasMatch(commit)) {
    throw const FormatException('Commit must be a hexadecimal Git id.');
  }
  final contract = await _readContract(root);
  final artifactsRoot = Directory(artifactsDirectory).absolute;
  final repository = contract['repository']!.toString();
  final tag = contract['tag']!.toString();
  final generated = <Map<String, dynamic>>[];
  for (final raw in contract['artifacts'] as List) {
    final item = Map<String, dynamic>.from(raw as Map);
    final filename = item['filename']!.toString();
    final file = File('${artifactsRoot.path}/$filename');
    if (!file.existsSync()) {
      throw FormatException('Missing required artifact: $filename');
    }
    if (item['public'] != true) {
      continue;
    }
    final signatureFile = File('${file.path}.update-signature');
    generated.add({
      ...item,
      'url': 'https://github.com/$repository/releases/download/$tag/$filename',
      'sha256': await sha256OfFile(file),
      'size': await file.length(),
      if (signatureFile.existsSync())
        'update_signature': (await signatureFile.readAsString()).trim(),
    });
  }
  final manifest = ReleaseManifest.fromJson({
    'schema_version': contract['schema_version'],
    'version': contract['version'],
    'build_number': contract['build_number'],
    'tag': tag,
    'commit': commit,
    'channel': contract['channel'],
    'repository': repository,
    'artifacts': generated,
  });
  final outputFile = File(output);
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(
    '${const JsonEncoder.withIndent('  ').convert(manifest.toJson())}\n',
  );
  await _writeChecksums(outputFile.parent, manifest);
  stdout.writeln('Generated ${outputFile.path}');
}

Future<void> _verifyManifest(
  File manifestFile, {
  String? artifactsDirectory,
}) async {
  final manifest = ReleaseManifest.fromJsonString(
    await manifestFile.readAsString(),
  );
  if (artifactsDirectory != null) {
    final directory = Directory(artifactsDirectory).absolute;
    for (final artifact in manifest.artifacts) {
      final file = File('${directory.path}/${artifact.filename}');
      if (!file.existsSync() ||
          await file.length() != artifact.size ||
          await sha256OfFile(file) != artifact.sha256) {
        throw FormatException(
          'Artifact verification failed: ${artifact.filename}',
        );
      }
    }
  }
  stdout.writeln('Release manifest valid: ${manifest.tag}');
}

Future<void> _generateAppcast(
  File manifestFile,
  File outputFile, {
  String? publishedAt,
}) async {
  final manifest = ReleaseManifest.fromJsonString(
    await manifestFile.readAsString(),
  );
  final date = publishedAt == null
      ? DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)
      : DateTime.parse(publishedAt).toUtc();
  await outputFile.parent.create(recursive: true);
  await outputFile.writeAsString(generateAppcastXml(manifest, date));
  stdout.writeln('Generated ${outputFile.path}');
}

Future<Map<String, dynamic>> _readContract(Directory root) async {
  final file = File('${root.path}/release/release-contract.json');
  final decoded = jsonDecode(await file.readAsString());
  if (decoded is! Map<String, dynamic>) {
    throw const FormatException('Release contract must be a JSON object.');
  }
  return decoded;
}

String _pubspecVersion(File file) {
  final match = RegExp(
    r'^version:\s*(\S+)\s*$',
    multiLine: true,
  ).firstMatch(file.readAsStringSync());
  if (match == null) throw FormatException('Missing version in ${file.path}');
  return match.group(1)!;
}

Future<void> _writeChecksums(
  Directory outputDirectory,
  ReleaseManifest manifest,
) async {
  final buffer = StringBuffer();
  for (final artifact in [
    ...manifest.artifacts.where((artifact) => artifact.public),
  ]..sort((left, right) => left.filename.compareTo(right.filename))) {
    buffer.writeln('${artifact.sha256}  ${artifact.filename}');
  }
  await File(
    '${outputDirectory.path}/SHA256SUMS',
  ).writeAsString(buffer.toString());
}

Map<String, String> _options(Iterable<String> arguments) {
  final values = <String, String>{};
  final list = arguments.toList();
  for (var index = 0; index < list.length; index++) {
    final key = list[index];
    if (!key.startsWith('--') || index + 1 >= list.length) {
      _usage('Expected --name value options.');
    }
    values[key.substring(2)] = list[++index];
  }
  return values;
}

String _required(Map<String, String> values, String key) {
  final value = values[key];
  if (value == null || value.isEmpty) _usage('Missing --$key.');
  return value;
}

Never _usage([String? error]) {
  if (error != null) stderr.writeln(error);
  stderr.writeln(
    'Usage: release_tool.dart <validate-contract|generate-manifest|verify-manifest|generate-appcast> [options]',
  );
  exit(64);
}
