import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'package:sanad_release_contract/release_contract.dart';

enum AgentUpdateStatus {
  upToDate('up_to_date'),
  updateAvailable('update_available'),
  updating('updating'),
  restartRequired('restart_required'),
  sourceManaged('source_managed'),
  unsupportedTarget('unsupported_target'),
  verificationFailed('verification_failed'),
  rollbackCompleted('rollback_completed'),
  failed('failed');

  const AgentUpdateStatus(this.wireName);
  final String wireName;
}

class AgentUpdateResult {
  const AgentUpdateResult({
    required this.status,
    required this.currentVersion,
    this.availableVersion,
    this.message,
    this.stagedPath,
  });

  final AgentUpdateStatus status;
  final String currentVersion;
  final String? availableVersion;
  final String? message;
  final String? stagedPath;

  bool get isSuccess => switch (status) {
    AgentUpdateStatus.upToDate ||
    AgentUpdateStatus.updateAvailable ||
    AgentUpdateStatus.restartRequired ||
    AgentUpdateStatus.sourceManaged ||
    AgentUpdateStatus.rollbackCompleted => true,
    _ => false,
  };

  Map<String, dynamic> toJson() => {
    'success': isSuccess,
    'status': status.wireName,
    'current_version': currentVersion,
    if (availableVersion != null) 'available_version': availableVersion,
    if (message != null) 'message': message,
  };
}

class AgentUpdateService {
  AgentUpdateService({
    required this.currentVersion,
    required this.executablePath,
    required this.isSourceManaged,
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
       architecture = architecture ?? _detectArchitecture();

  final String currentVersion;
  final String executablePath;
  final bool isSourceManaged;
  final Uri manifestUri;
  final String operatingSystem;
  final String architecture;
  final http.Client _client;

  Future<AgentUpdateResult> check() async {
    if (isSourceManaged) {
      return AgentUpdateResult(
        status: AgentUpdateStatus.sourceManaged,
        currentVersion: currentVersion,
        message:
            'This agent is running from source. Update the checkout manually; Sanad will not run Git or FVM.',
      );
    }
    try {
      final manifest = await _fetchManifest();
      final available = manifest.version.toString();
      final current = ReleaseVersion.parse(currentVersion);
      if (manifest.version.compareTo(current) <= 0) {
        return AgentUpdateResult(
          status: AgentUpdateStatus.upToDate,
          currentVersion: currentVersion,
          availableVersion: available,
        );
      }
      final artifact = _selectArtifact(manifest);
      if (artifact == null) {
        return AgentUpdateResult(
          status: AgentUpdateStatus.unsupportedTarget,
          currentVersion: currentVersion,
          availableVersion: available,
        );
      }
      return AgentUpdateResult(
        status: AgentUpdateStatus.updateAvailable,
        currentVersion: currentVersion,
        availableVersion: available,
      );
    } on FormatException catch (error) {
      return AgentUpdateResult(
        status: AgentUpdateStatus.verificationFailed,
        currentVersion: currentVersion,
        message: error.message,
      );
    } catch (error) {
      return AgentUpdateResult(
        status: AgentUpdateStatus.failed,
        currentVersion: currentVersion,
        message: 'Unable to check for updates: $error',
      );
    }
  }

  Future<AgentUpdateResult> update() async {
    if (isSourceManaged) return check();
    RandomAccessFile? lockHandle;
    File? stagedFile;
    var preserveStagedFile = false;
    try {
      final manifest = await _fetchManifest();
      final available = manifest.version.toString();
      final current = ReleaseVersion.parse(currentVersion);
      if (manifest.version.compareTo(current) <= 0) {
        return AgentUpdateResult(
          status: AgentUpdateStatus.upToDate,
          currentVersion: currentVersion,
          availableVersion: available,
        );
      }
      final artifact = _selectArtifact(manifest);
      if (artifact == null) {
        return AgentUpdateResult(
          status: AgentUpdateStatus.unsupportedTarget,
          currentVersion: currentVersion,
          availableVersion: available,
        );
      }

      final executable = File(executablePath);
      await executable.parent.create(recursive: true);
      final lockFile = File('$executablePath.update.lock');
      lockHandle = await lockFile.open(mode: FileMode.write);
      await lockHandle.lock(FileLock.exclusive);

      final staged = File('$executablePath.${manifest.version}.staged');
      stagedFile = staged;
      final response = await _client.send(http.Request('GET', artifact.url));
      if (response.statusCode != HttpStatus.ok) {
        throw HttpException(
          'Artifact download failed with HTTP ${response.statusCode}.',
        );
      }
      final sink = staged.openWrite();
      var received = 0;
      await for (final chunk in response.stream) {
        received += chunk.length;
        sink.add(chunk);
      }
      await sink.close();

      if (received != artifact.size ||
          await sha256OfFile(staged) != artifact.sha256) {
        await staged.delete();
        return AgentUpdateResult(
          status: AgentUpdateStatus.verificationFailed,
          currentVersion: currentVersion,
          availableVersion: available,
          message: 'Downloaded artifact failed size or SHA-256 verification.',
        );
      }
      if (!await verifyPlatformCodeSignature(
        staged,
        operatingSystem: operatingSystem,
      )) {
        await staged.delete();
        return AgentUpdateResult(
          status: AgentUpdateStatus.verificationFailed,
          currentVersion: currentVersion,
          availableVersion: available,
          message:
              'Downloaded artifact failed platform signature verification.',
        );
      }

      if (Platform.isWindows || operatingSystem == 'windows') {
        preserveStagedFile = true;
        return AgentUpdateResult(
          status: AgentUpdateStatus.restartRequired,
          currentVersion: currentVersion,
          availableVersion: available,
          message: 'Verified update staged for replacement during restart.',
          stagedPath: staged.path,
        );
      }

      final backup = File('$executablePath.rollback');
      if (backup.existsSync()) await backup.delete();
      if (executable.existsSync()) await executable.rename(backup.path);
      try {
        await staged.rename(executable.path);
        final chmod = await Process.run('chmod', ['700', executable.path]);
        if (chmod.exitCode != 0) {
          throw FileSystemException('Unable to mark update executable.');
        }
      } catch (_) {
        if (executable.existsSync()) await executable.delete();
        if (backup.existsSync()) await backup.rename(executable.path);
        return AgentUpdateResult(
          status: AgentUpdateStatus.rollbackCompleted,
          currentVersion: currentVersion,
          availableVersion: available,
          message: 'Replacement failed; the previous executable was restored.',
        );
      }

      return AgentUpdateResult(
        status: AgentUpdateStatus.restartRequired,
        currentVersion: currentVersion,
        availableVersion: available,
        message: 'Verified update installed. Restart the Sanad service.',
      );
    } on FormatException catch (error) {
      return AgentUpdateResult(
        status: AgentUpdateStatus.verificationFailed,
        currentVersion: currentVersion,
        message: error.message,
      );
    } catch (error) {
      return AgentUpdateResult(
        status: AgentUpdateStatus.failed,
        currentVersion: currentVersion,
        message: 'Update failed: $error',
      );
    } finally {
      if (!preserveStagedFile && stagedFile?.existsSync() == true) {
        await stagedFile!.delete();
      }
      if (lockHandle != null) {
        await lockHandle.unlock();
        await lockHandle.close();
      }
    }
  }

  Future<bool> scheduleWindowsReplacement(AgentUpdateResult result) async {
    final stagedPath = result.stagedPath;
    if (stagedPath == null ||
        !(Platform.isWindows || operatingSystem == 'windows')) {
      return false;
    }
    final escapedExecutable = executablePath.replaceAll("'", "''");
    final escapedStaged = stagedPath.replaceAll("'", "''");
    final script =
        r'''
$ErrorActionPreference = 'Stop'
$target = '__TARGET__'
$staged = '__STAGED__'
$backup = "$target.rollback"
$deadline = (Get-Date).AddSeconds(60)
$ready = $false
while ((Get-Date) -lt $deadline) {
  try {
    if (Test-Path $backup) { Remove-Item -LiteralPath $backup -Force }
    if (Test-Path $target) { Move-Item -LiteralPath $target -Destination $backup -Force }
    $ready = $true
    break
  } catch {
    Start-Sleep -Milliseconds 500
  }
}
if (-not $ready) { exit 1 }
try {
  Move-Item -LiteralPath $staged -Destination $target -Force
  & $target service start
  if ($LASTEXITCODE -ne 0) { throw 'Service restart failed.' }
  exit 0
} catch {
  if (Test-Path $target) { Remove-Item -LiteralPath $target -Force }
  if (Test-Path $backup) { Move-Item -LiteralPath $backup -Destination $target -Force }
  exit 1
}
'''
            .replaceFirst('__TARGET__', escapedExecutable)
            .replaceFirst('__STAGED__', escapedStaged);
    final bytes = BytesBuilder(copy: false);
    for (final codeUnit in script.codeUnits) {
      bytes.add([codeUnit & 0xff, codeUnit >> 8]);
    }
    final encoded = base64Encode(bytes.takeBytes());
    await Process.start(
      'powershell.exe',
      ['-NoProfile', '-NonInteractive', '-EncodedCommand', encoded],
      mode: ProcessStartMode.detached,
      runInShell: false,
    );
    return true;
  }

  Future<ReleaseManifest> _fetchManifest() async {
    final response = await _client.get(
      manifestUri,
      headers: const {'User-Agent': 'sanad-agent'},
    );
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException(
        'Manifest request failed with HTTP ${response.statusCode}.',
      );
    }
    return ReleaseManifest.fromJsonString(utf8.decode(response.bodyBytes));
  }

  ReleaseArtifact? _selectArtifact(ReleaseManifest manifest) {
    return manifest.findArtifact(
      component: 'agent',
      platform: operatingSystem == 'macos' ? 'macos' : operatingSystem,
      architecture: architecture,
      publicOnly: true,
    );
  }

  static String _detectArchitecture() {
    final value = Abi.current().toString().toLowerCase();
    if (value.contains('arm64')) return 'arm64';
    return 'x64';
  }
}
