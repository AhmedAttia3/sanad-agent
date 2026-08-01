import 'package:sanad_agent/core/config.dart';
import 'package:sanad_agent/core/provider_runtime/env_file_service.dart';
import 'package:sanad_agent/core/provider_runtime/runtime_recovery_service.dart';

class DeviceSettingsUpdate {
  const DeviceSettingsUpdate({
    required this.snapshot,
    required this.restartRequired,
  });

  final Map<String, dynamic> snapshot;
  final bool restartRequired;
}

/// Whitelisted, agent-owned runtime settings exposed through the Sanad
/// protocol. Secrets are accepted for mutation but never returned.
class DeviceSettingsService {
  DeviceSettingsService({
    required Config config,
    required EnvFileService envFileService,
    required RuntimeRecoveryService runtimeRecovery,
  }) : _config = config,
       _envFileService = envFileService,
       _runtimeRecovery = runtimeRecovery;

  static const supportedWebSearchProviders = {'ddg', 'serper'};

  final Config _config;
  final EnvFileService _envFileService;
  final RuntimeRecoveryService _runtimeRecovery;

  Map<String, dynamic> snapshot() => {
    'cloud_connection': {
      'enabled': _config.enableGateway,
      'managed_externally': _config.isProcessManaged('ENABLE_GATEWAY'),
    },
    'computer_use': {
      'enabled': _config.computerUse,
      'managed_externally': _config.isProcessManaged('COMPUTER_USE'),
    },
    'web_search': {
      'provider': _config.webSearchProvider,
      'serper_configured': _config.serperApiKey.isNotEmpty,
      'provider_managed_externally': _config.isProcessManaged(
        'WEB_SEARCH_PROVIDER',
      ),
      'serper_key_managed_externally': _config.isProcessManaged(
        'SERPER_API_KEY',
      ),
    },
    'provider_auto_failover': {
      'enabled': _runtimeRecovery.autoFailoverEnabled,
      'managed_externally': _config.isProcessManaged('PROVIDER_AUTO_FAILOVER'),
    },
  };

  Future<DeviceSettingsUpdate> update(Map<String, dynamic> changes) async {
    if (changes.isEmpty) {
      throw const FormatException('At least one setting change is required.');
    }

    const allowed = {
      'cloud_connection_enabled',
      'computer_use_enabled',
      'web_search_provider',
      'serper_api_key',
      'provider_auto_failover_enabled',
    };
    final unknown = changes.keys.where((key) => !allowed.contains(key));
    if (unknown.isNotEmpty) {
      throw FormatException('Unsupported device setting: ${unknown.first}');
    }

    final updates = <String, String>{};
    var restartRequired = false;

    void requireWritable(String setting, String envKey) {
      if (_config.isProcessManaged(envKey)) {
        throw StateError('$setting is managed by the process environment.');
      }
    }

    bool requireBool(String key) {
      final value = changes[key];
      if (value is! bool) {
        throw FormatException('$key must be a boolean.');
      }
      return value;
    }

    if (changes.containsKey('cloud_connection_enabled')) {
      requireWritable('Cloud Connection', 'ENABLE_GATEWAY');
      updates['ENABLE_GATEWAY'] = requireBool(
        'cloud_connection_enabled',
      ).toString();
      restartRequired = true;
    }
    if (changes.containsKey('computer_use_enabled')) {
      requireWritable('Computer Use', 'COMPUTER_USE');
      updates['COMPUTER_USE'] = requireBool('computer_use_enabled').toString();
    }
    if (changes.containsKey('web_search_provider')) {
      requireWritable('Web Search provider', 'WEB_SEARCH_PROVIDER');
      final provider = changes['web_search_provider'];
      if (provider is! String ||
          !supportedWebSearchProviders.contains(provider.toLowerCase())) {
        throw const FormatException(
          'web_search_provider must be ddg or serper.',
        );
      }
      updates['WEB_SEARCH_PROVIDER'] = provider.toLowerCase();
    }
    if (changes.containsKey('serper_api_key')) {
      requireWritable('Serper API key', 'SERPER_API_KEY');
      final apiKey = changes['serper_api_key'];
      if (apiKey is! String) {
        throw const FormatException('serper_api_key must be a string.');
      }
      updates['SERPER_API_KEY'] = apiKey.trim();
    }
    if (changes.containsKey('provider_auto_failover_enabled')) {
      requireWritable('Provider Auto Failover', 'PROVIDER_AUTO_FAILOVER');
      updates['PROVIDER_AUTO_FAILOVER'] = requireBool(
        'provider_auto_failover_enabled',
      ).toString();
    }

    // Validation completes before the single environment-file mutation so an
    // invalid mixed request cannot partially apply.
    await _envFileService.upsert(updates);
    _config.reload();
    if (changes.containsKey('provider_auto_failover_enabled')) {
      _runtimeRecovery.autoFailoverEnabled =
          changes['provider_auto_failover_enabled'] as bool;
    }

    return DeviceSettingsUpdate(
      snapshot: snapshot(),
      restartRequired: restartRequired,
    );
  }
}
