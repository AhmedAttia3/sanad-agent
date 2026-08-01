import 'dart:async';

import 'package:sanad_client/infrastructure/socket/event_deduplicator.dart';
import 'package:test/test.dart';

import '../../mocks/mock_socket_service.dart';

/// Phase 27 — verifies that the same canonical event delivered over both the
/// local and cloud transports is applied exactly once by the client, thanks
/// to the shared `EventDeduplicator` keyed by `event_id`.
void main() {
  test(
    'the same event_id over cloud and local is delivered once',
    () async {
      final cloud = FakeSanadSocketService(hardwareId: 'hw-1');
      final local = FakeSanadSocketService(hardwareId: 'hw-1');
      // Share one deduplicator across both transports, exactly as the
      // DeviceConnectionCoordinator wires them in production.
      final sharedDedup = EventDeduplicator();
      cloud.eventDeduplicator = sharedDedup;
      local.eventDeduplicator = sharedDedup;

      final cloudEvents = <Map<String, dynamic>>[];
      final localEvents = <Map<String, dynamic>>[];
      cloud.events.listen(cloudEvents.add);
      local.events.listen(localEvents.add);

      final envelope = <String, dynamic>{
        'type': 'device_event',
        'event': 'final_answer',
        'event_id': 'evt_shared_1',
        'device_id': 'device-a',
        'payload': {'content': 'hi'},
      };

      // Cloud delivers first.
      cloud.debugEmitDeviceEvent(envelope);
      // Local delivers the same event_id shortly after.
      local.debugEmitDeviceEvent(envelope);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cloudEvents.length, 1, reason: 'cloud delivers the event once');
      expect(localEvents.length, 0, reason: 'local duplicate is dropped by the shared deduplicator');

      cloud.dispose();
      local.dispose();
    },
  );

  test(
    'distinct event_ids over cloud and local are each delivered',
    () async {
      final cloud = FakeSanadSocketService(hardwareId: 'hw-1');
      final local = FakeSanadSocketService(hardwareId: 'hw-1');
      final sharedDedup = EventDeduplicator();
      cloud.eventDeduplicator = sharedDedup;
      local.eventDeduplicator = sharedDedup;

      final cloudEvents = <Map<String, dynamic>>[];
      final localEvents = <Map<String, dynamic>>[];
      cloud.events.listen(cloudEvents.add);
      local.events.listen(localEvents.add);

      cloud.debugEmitDeviceEvent({
        'type': 'device_event',
        'event': 'final_answer',
        'event_id': 'evt_cloud_only',
        'device_id': 'device-a',
        'payload': {'content': 'cloud'},
      });
      local.debugEmitDeviceEvent({
        'type': 'device_event',
        'event': 'final_answer',
        'event_id': 'evt_local_only',
        'device_id': 'device-a',
        'payload': {'content': 'local'},
      });

      await Future<void>.delayed(const Duration(milliseconds: 10));

      expect(cloudEvents.length, 1);
      expect(localEvents.length, 1);

      cloud.dispose();
      local.dispose();
    },
  );

  test(
    'events without event_id are not deduplicated (backward compat)',
    () async {
      final cloud = FakeSanadSocketService(hardwareId: 'hw-1');
      final local = FakeSanadSocketService(hardwareId: 'hw-1');
      final sharedDedup = EventDeduplicator();
      cloud.eventDeduplicator = sharedDedup;
      local.eventDeduplicator = sharedDedup;

      final cloudEvents = <Map<String, dynamic>>[];
      final localEvents = <Map<String, dynamic>>[];
      cloud.events.listen(cloudEvents.add);
      local.events.listen(localEvents.add);

      final envelope = <String, dynamic>{
        'type': 'device_event',
        'event': 'final_answer',
        // no event_id
        'device_id': 'device-a',
        'payload': {'content': 'hi'},
      };
      cloud.debugEmitDeviceEvent(envelope);
      local.debugEmitDeviceEvent(envelope);

      await Future<void>.delayed(const Duration(milliseconds: 10));

      // Without event_id the deduplicator lets both through; producers are
      // expected to stamp event_id, so this is a backward-compat fallback.
      expect(cloudEvents.length, 1);
      expect(localEvents.length, 1);

      cloud.dispose();
      local.dispose();
    },
  );

  test('clear() on logout resets dedup state across transports', () async {
    final cloud = FakeSanadSocketService(hardwareId: 'hw-1');
    final local = FakeSanadSocketService(hardwareId: 'hw-1');
    final sharedDedup = EventDeduplicator();
    cloud.eventDeduplicator = sharedDedup;
    local.eventDeduplicator = sharedDedup;

    final cloudEvents = <Map<String, dynamic>>[];
    cloud.events.listen(cloudEvents.add);

    final envelope = <String, dynamic>{
      'type': 'device_event',
      'event': 'final_answer',
      'event_id': 'evt_logout',
      'device_id': 'device-a',
      'payload': {'content': 'hi'},
    };
    cloud.debugEmitDeviceEvent(envelope);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cloudEvents.length, 1);

    // After logout the dedup state is cleared; a later replay of the same
    // event_id (e.g. re-hydration after re-login) is processed again.
    sharedDedup.clear();
    cloud.debugEmitDeviceEvent(envelope);
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(cloudEvents.length, 2);

    cloud.dispose();
    local.dispose();
  });
}
