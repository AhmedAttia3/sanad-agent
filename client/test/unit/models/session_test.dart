/// Tests for [Session] model — Scenario C5-4.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';

void main() {
  group('C5-4: Session.fromJson', () {
    test('parses all standard fields correctly', () {
      final json = {
        'id': 'session-uuid-123',
        'title': 'My Session',
        'device_id': 'device-uuid',
        'created_at': '2026-02-28T10:00:00.000',
        'updated_at': '2026-02-28T11:30:00.000',
        'last_message_at': '2026-02-28T12:00:00.000',
        'metadata': {'key': 'value'},
      };

      final session = Session.fromJson(json);

      expect(session.id, 'session-uuid-123');
      expect(session.title, 'My Session');
      expect(session.deviceId, 'device-uuid');
      expect(session.createdAt, DateTime.parse('2026-02-28T10:00:00.000'));
      expect(session.updatedAt, DateTime.parse('2026-02-28T11:30:00.000'));
      expect(session.lastMessageAt, isNotNull);
      expect(session.metadata?['key'], 'value');
    });

    test('uses defaults when optional fields are missing', () {
      final json = {
        'id': 'session-abc',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final session = Session.fromJson(json);

      expect(session.title, 'New Chat'); // default title
      expect(session.deviceId, isNull);
      expect(session.lastMessageAt, isNull);
      expect(session.metadata, isNull);
    });

    test('falls back to session_id when id is absent', () {
      final json = {
        'session_id': 'device:main:session-abc',
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final session = Session.fromJson(json);

      expect(session.id, 'device:main:session-abc');
    });

    test('id is empty string when neither id nor session_id is provided', () {
      final json = {
        'created_at': '2026-01-01T00:00:00.000',
        'updated_at': '2026-01-01T00:00:00.000',
      };

      final session = Session.fromJson(json);

      expect(session.id, '');
    });
  });

  group('Session constructor', () {
    test('stores all provided values', () {
      final now = DateTime(2026, 2, 28, 10, 0);

      final session = Session(
        id: 'direct-id',
        title: 'Direct Title',
        deviceId: 'device-1',
        createdAt: now,
        updatedAt: now,
        metadata: {'source': 'direct'},
      );

      expect(session.id, 'direct-id');
      expect(session.title, 'Direct Title');
      expect(session.deviceId, 'device-1');
      expect(session.createdAt, now);
      expect(session.metadata?['source'], 'direct');
    });
  });
}
