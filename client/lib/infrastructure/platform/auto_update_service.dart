import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sanad_client/core/config/app_config.dart';
import 'package:sanad_client/utils/app_platform.dart';
import 'package:sanad_release_contract/release_contract.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:auto_updater/auto_updater.dart';

class AutoUpdateService {
  static final _logger = Logger('AutoUpdateService');

  static final AutoUpdateService _instance = AutoUpdateService._internal();

  factory AutoUpdateService() {
    return _instance;
  }

  AutoUpdateService._internal();

  bool _isInitialized = false;

  // EastStar AI-owned Appcast endpoint.
  static const String _feedUrl = 'https://updates.sanad.eaststarai.com/appcast.xml';
  static final Uri _manifestUrl = Uri.parse(
    'https://github.com/EastStarAI/sanad-agent/releases/latest/download/release-manifest.json',
  );

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (AppConfig.isSourceRun) {
      _logger.info('Client self-update is disabled for source-managed runs.');
      _isInitialized = true;
      return;
    }

    if (AppPlatform.isMacOS || AppPlatform.isWindows) {
      await _initAutoUpdater();
    } else if (AppPlatform.isIOS) {
      _logger.info('iOS updates are owned by Internal TestFlight.');
    } else if (AppPlatform.isWeb) {
      await _checkWebVersion();
    }

    _isInitialized = true;
  }

  Future<void> _initAutoUpdater() async {
    // 1. Set the feed URL
    await autoUpdater.setFeedURL(_feedUrl);

    await autoUpdater.setScheduledCheckInterval(86400);
  }

  Future<void> checkForUpdates() async {
    if (AppConfig.isSourceRun) {
      _logger.info('Source-managed clients must be updated by the developer.');
      return;
    }
    if (AppPlatform.isMacOS || AppPlatform.isWindows) {
      await autoUpdater.checkForUpdates();
    } else if (AppPlatform.isLinux || AppPlatform.isAndroid) {
      final artifact = await _findManualUpdate();
      if (artifact != null) {
        await launchUrl(artifact.url, mode: LaunchMode.externalApplication);
      }
    } else if (AppPlatform.isWeb) {
      await _checkWebVersion();
    } else if (AppPlatform.isIOS) {
      _logger.info('Install iOS updates from Internal TestFlight.');
    } else {
      _logger.info('Manual update check not supported on this platform.');
    }
  }

  Future<ReleaseArtifact?> _findManualUpdate() async {
    try {
      final response = await http.get(
        _manifestUrl,
        headers: const {'User-Agent': 'sanad-client'},
      );
      if (response.statusCode != 200) return null;
      final manifest = ReleaseManifest.fromJsonString(response.body);
      final package = await PackageInfo.fromPlatform();
      if (manifest.version.compareTo(ReleaseVersion.parse(package.version)) <= 0) {
        return null;
      }
      return manifest.findArtifact(
        component: 'client',
        platform: AppPlatform.isAndroid ? 'android' : 'linux',
        architecture: AppPlatform.isAndroid ? 'universal' : 'x64',
        format: AppPlatform.isAndroid ? 'apk' : 'tar.gz',
        publicOnly: true,
      );
    } catch (error) {
      _logger.warning('Unable to check the manual update channel: $error');
      return null;
    }
  }

  Future<void> _checkWebVersion() async {
    try {
      final response = await http.get(
        Uri.base.resolve('version.json'),
        headers: const {'Cache-Control': 'no-cache'},
      );
      if (response.statusCode != 200) return;
      final payload = jsonDecode(response.body);
      final published = payload is Map ? payload['version']?.toString() : null;
      final current = (await PackageInfo.fromPlatform()).version;
      if (published != null && published != current) {
        _logger.info('A newer Web client is available after the next reload.');
      }
    } catch (_) {
      // Version discovery is best effort and must not block application startup.
    }
  }
}
