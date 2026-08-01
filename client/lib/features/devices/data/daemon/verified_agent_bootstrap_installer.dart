import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:sanad_release_contract/release_contract.dart';

class VerifiedAgentBootstrapInstaller {
  VerifiedAgentBootstrapInstaller({
    required this.targetPath,
    http.Client? client,
    Uri? manifestUri,
    String? operatingSystem,
    String? architecture,
  }) : _client = client ?? http.Client(),
       manifestUri =
           manifestUri ??
           Uri.parse(
             'https://github.com/EastStarAI/sanad-agent/releases/latest/download/release-manifest.json',
           ),
       operatingSystem = operatingSystem ?? Platform.operatingSystem,
       architecture = architecture ?? _architecture();

  final String targetPath;
  final Uri manifestUri;
  final String operatingSystem;
  final String architecture;
  final http.Client _client;

  Future<bool> install({void Function(double progress)? onProgress}) async {
    final manifestResponse = await _client.get(
      manifestUri,
      headers: const {'User-Agent': 'sanad-client'},
    );
    if (manifestResponse.statusCode != HttpStatus.ok) return false;
    final manifest = ReleaseManifest.fromJsonString(manifestResponse.body);
    final platform = operatingSystem == 'macos' ? 'macos' : operatingSystem;
    final artifact = manifest.findArtifact(
      component: 'agent',
      platform: platform,
      architecture: architecture,
      publicOnly: true,
    );
    if (artifact == null || artifact.signatureType.trim().isEmpty) return false;

    final target = File(targetPath);
    await target.parent.create(recursive: true);
    final staged = File('$targetPath.bootstrap-staged');
    final response = await _client.send(http.Request('GET', artifact.url));
    if (response.statusCode != HttpStatus.ok) return false;
    final sink = staged.openWrite();
    var downloaded = 0;
    await for (final chunk in response.stream) {
      downloaded += chunk.length;
      sink.add(chunk);
      if (artifact.size > 0) onProgress?.call(downloaded / artifact.size);
    }
    await sink.close();
    if (downloaded != artifact.size || await sha256OfFile(staged) != artifact.sha256) {
      await staged.delete();
      return false;
    }
    if (!await verifyPlatformCodeSignature(
      staged,
      operatingSystem: operatingSystem,
    )) {
      await staged.delete();
      return false;
    }

    final backup = File('$targetPath.rollback');
    if (backup.existsSync()) await backup.delete();
    if (target.existsSync()) await target.rename(backup.path);
    try {
      await staged.rename(target.path);
      if (!Platform.isWindows) {
        final chmod = await Process.run('chmod', ['700', target.path]);
        if (chmod.exitCode != 0) throw const FileSystemException('chmod');
      }
      return true;
    } catch (_) {
      if (target.existsSync()) await target.delete();
      if (backup.existsSync()) await backup.rename(target.path);
      return false;
    }
  }

  static String _architecture() {
    return Platform.version.toLowerCase().contains('arm64') ? 'arm64' : 'x64';
  }
}
