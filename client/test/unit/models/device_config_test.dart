/// Tests for [DeviceConfig] model — Scenario C5-5.
///
/// Covers:
///   - [DeviceConfig.fromJson] (local storage format) + [DeviceConfig.toJson] round-trip
///   - [DeviceConfig.fromApiResponse] (API response format)
///   - [DeviceConfig.copyWith]
library;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/devices/presentation/utils/device_ui_mapper.dart';

void main() {
  // ──────────────────────────────────────────────────────────────────────────
  // C5-5 — fromJson / toJson round-trip
  // ──────────────────────────────────────────────────────────────────────────
  group('C5-5: DeviceConfig.fromJson + toJson round-trip', () {
    test('config survives round-trip', () {
      final original = DeviceConfig(
        id: 'agent-uuid-1',
        name: 'My Device',
        hardwareId: 'device-uuid',
        isOnline: true,
        createdAt: DateTime(2026, 2, 28),
        updatedAt: DateTime(2026, 2, 28, 10),
      );

      final json = original.toJson();
      final restored = DeviceConfig.fromJson(json);

      expect(restored.id, original.id);
      expect(restored.name, original.name);
      expect(restored.hardwareId, original.hardwareId);
      expect(restored.isOnline, original.isOnline);
      expect(restored.createdAt?.toIso8601String(), original.createdAt?.toIso8601String());
      expect(restored.updatedAt?.toIso8601String(), original.updatedAt?.toIso8601String());
    });

    test('config with token survives round-trip', () {
      final original = DeviceConfig(id: 'oc-uuid', name: 'My Computer', token: 'oc-secret-token', isOnline: false);

      final json = original.toJson();
      final restored = DeviceConfig.fromJson(json);

      expect(restored.id, 'oc-uuid');
      expect(restored.token, 'oc-secret-token');
      expect(restored.isOnline, isFalse);
    });

    test('toJson omits null optional fields', () {
      final config = DeviceConfig(id: 'min-id', name: 'Minimal');

      final json = config.toJson();

      expect(json.containsKey('hardwareId'), isFalse);
      expect(json.containsKey('token'), isFalse);
      expect(json.containsKey('sessionId'), isFalse);
      expect(json.containsKey('metadata'), isFalse);
      expect(json.containsKey('createdAt'), isFalse);
      expect(json.containsKey('updatedAt'), isFalse);
    });

    test('toJson always includes id, name, isOnline', () {
      final config = DeviceConfig(id: 'x', name: 'X', isOnline: true);

      final json = config.toJson();

      expect(json['id'], 'x');
      expect(json['name'], 'X');
      expect(json['isOnline'], isTrue);
    });

    test('sessionId is preserved in round-trip', () {
      final config = DeviceConfig(id: 'a', name: 'A', sessionId: 'session-123');

      final json = config.toJson();
      final restored = DeviceConfig.fromJson(json);

      expect(restored.sessionId, 'session-123');
    });

    test('metadata is preserved in round-trip', () {
      final config = DeviceConfig(id: 'a', name: 'A', metadata: {'key': 'value', 'count': 42});

      final json = config.toJson();
      final restored = DeviceConfig.fromJson(json);

      expect(restored.metadata?['key'], 'value');
      expect(restored.metadata?['count'], 42);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // fromApiResponse — API JSON format
  // ──────────────────────────────────────────────────────────────────────────
  group('DeviceConfig.fromApiResponse', () {
    test('parses device from API response', () {
      final json = {
        'id': 'api-uuid',
        'name': 'API Device',
        'hardware_id': 'dev-uuid',
        'token': null,
        'is_online': true,
        'created_at': '2026-02-28T00:00:00',
        'updated_at': '2026-02-28T01:00:00',
      };

      final config = DeviceConfig.fromApiResponse(json);

      expect(config.id, 'api-uuid');
      expect(config.name, 'API Device');
      expect(config.hardwareId, 'dev-uuid');
      expect(config.isOnline, isTrue);
    });

    test('is_online defaults to false when absent', () {
      final json = {
        'id': 'x',
        'name': 'X',
        'created_at': '2026-02-28T00:00:00',
        'updated_at': '2026-02-28T00:00:00',
      };

      final config = DeviceConfig.fromApiResponse(json);

      expect(config.isOnline, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // copyWith
  // ──────────────────────────────────────────────────────────────────────────
  group('DeviceConfig.copyWith', () {
    test('copyWith replaces only specified fields', () {
      final original = DeviceConfig(id: 'orig-id', name: 'Original', isOnline: false);

      final copy = original.copyWith(name: 'Updated', isOnline: true);

      expect(copy.id, 'orig-id'); // unchanged
      expect(copy.name, 'Updated'); // changed
      expect(copy.isOnline, isTrue); // changed
    });

    test('equality includes fields that affect rendered state', () {
      final a = DeviceConfig(id: 'same-id', name: 'A');
      final b = DeviceConfig(id: 'same-id', name: 'B');

      expect(a == b, isFalse);
    });

    test('same values are equal', () {
      final a = DeviceConfig(id: 'same-id', name: 'A', isOnline: true);
      final b = DeviceConfig(id: 'same-id', name: 'A', isOnline: true);

      expect(a == b, isTrue);
      expect(a.hashCode, b.hashCode);
    });

    test('different ids are not equal', () {
      final a = DeviceConfig(id: 'id-1', name: 'A');
      final b = DeviceConfig(id: 'id-2', name: 'A');

      expect(a == b, isFalse);
    });
  });

  // ──────────────────────────────────────────────────────────────────────────
  // DeviceConfigUI — extension tests
  // ──────────────────────────────────────────────────────────────────────────
  group('DeviceConfigUI Extension', () {
    test('returns correct icons based on platform metadata', () {
      final mac = DeviceConfig(id: '1', name: 'Mac', metadata: {'platform': 'macos'});
      final win = DeviceConfig(id: '2', name: 'Win', metadata: {'platform': 'windows'});
      final linux = DeviceConfig(id: '3', name: 'Linux', metadata: {'platform': 'linux'});
      final unknown = DeviceConfig(id: '4', name: 'Unknown', metadata: {'platform': 'unknown'});
      final noPlatform = DeviceConfig(id: '5', name: 'No Platform', metadata: {});
      final noMetadata = DeviceConfig(id: '6', name: 'No Metadata');

      expect(mac.icon, Icons.apple);
      expect(win.icon, Icons.window);
      expect(linux.icon, Icons.terminal);
      expect(unknown.icon, Icons.computer);
      expect(noPlatform.icon, Icons.computer);
      expect(noMetadata.icon, Icons.computer);
    });

    testWidgets('buildIcon returns correct Widget based on platform metadata', (WidgetTester tester) async {
      final mac = DeviceConfig(id: '1', name: 'Mac', metadata: {'platform': 'macos'});
      final win = DeviceConfig(id: '2', name: 'Win', metadata: {'platform': 'windows'});
      final linux = DeviceConfig(id: '3', name: 'Linux', metadata: {'platform': 'linux'});

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              final macIcon = mac.buildIcon(context);
              final winIcon = win.buildIcon(context);
              final linuxIcon = linux.buildIcon(context);

              expect(macIcon, isA<Icon>());
              expect((macIcon as Icon).icon, Icons.apple);

              expect(winIcon, isA<Icon>());
              expect((winIcon as Icon).icon, Icons.window);

              expect(linuxIcon, isA<SvgPicture>());
              return const Placeholder();
            },
          ),
        ),
      );
    });

    testWidgets('returns correct colors based on online/offline status', (WidgetTester tester) async {
      final onlineDevice = DeviceConfig(id: '1', name: 'Online Device', isOnline: true);
      final offlineDevice = DeviceConfig(id: '2', name: 'Offline Device', isOnline: false);

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (BuildContext context) {
              expect(onlineDevice.color(context), Theme.of(context).colorScheme.primary);
              expect(offlineDevice.color(context), const Color(0xFF9E9E9E));

              expect(
                onlineDevice.iconBackground(context),
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
              );
              expect(offlineDevice.iconBackground(context), const Color(0xFF9E9E9E).withValues(alpha: 0.2));
              return const Placeholder();
            },
          ),
        ),
      );
    });
  });
}
