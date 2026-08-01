import 'package:sanad_agent/infrastructure/platform/automation_service_factory.dart';
import 'package:sanad_agent/interfaces/platforms/sanad_gateway/protocol/canonical_events.dart';
import 'package:sanad_agent/interfaces/runtime/device_settings_service.dart';

import '../sanad_protocol_bridge.dart';

class DeviceSettingsCommandResult {
  const DeviceSettingsCommandResult({
    required this.envelope,
    this.restartRequired = false,
  });

  final Map<String, dynamic> envelope;
  final bool restartRequired;
}

/// Handles the small, whitelisted set of device runtime preferences without
/// depending on whether the request arrived over local or cloud transport.
class DeviceSettingsCommandHandler {
  DeviceSettingsCommandHandler({
    required DeviceSettingsService settings,
    required SanadProtocolBridge bridge,
  }) : _settings = settings,
       _bridge = bridge;

  final DeviceSettingsService _settings;
  final SanadProtocolBridge _bridge;

  Future<Map<String, dynamic>> buildSnapshotEnvelope(
    CanonicalEvent event,
  ) async {
    final permissions = await AutomationServiceFactory.instance
        .checkPermissions();
    return _bridge.buildAgentEventEnvelope(
      CanonicalEvent(
        type: CanonicalEventTypes.deviceSettingsSnapshot,
        payload: {
          'request_id': event.payload['request_id'],
          ..._settings.snapshot(),
          'computer_use_permissions_granted': permissions,
        },
      ),
    );
  }

  Future<DeviceSettingsCommandResult> buildUpdateEnvelope(
    CanonicalEvent event,
  ) async {
    final requestId = event.payload['request_id'];
    try {
      final changes = Map<String, dynamic>.from(
        event.payload['changes'] as Map? ?? const {},
      );
      final result = await _settings.update(changes);
      final permissions = await AutomationServiceFactory.instance
          .checkPermissions();
      return DeviceSettingsCommandResult(
        restartRequired: result.restartRequired,
        envelope: _bridge.buildAgentEventEnvelope(
          CanonicalEvent(
            type: CanonicalEventTypes.deviceSettingsUpdated,
            payload: {
              'request_id': requestId,
              ...result.snapshot,
              'computer_use_permissions_granted': permissions,
              'restart_required': result.restartRequired,
            },
          ),
        ),
      );
    } on Object catch (error) {
      return DeviceSettingsCommandResult(
        envelope: _bridge.buildAgentEventEnvelope(
          CanonicalEvent(
            type: 'error',
            payload: {
              'request_id': requestId,
              'code': 'invalid_device_settings',
              'message': error.toString(),
            },
          ),
        ),
      );
    }
  }
}
