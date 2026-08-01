import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/domain/models/session_route_snapshot.dart';
import 'package:sanad_client/features/conversations/domain/stores/session_route_registry.dart';

void main() {
  SessionRouteSnapshot route({
    int revision = 1,
    String provider = 'provider-a',
    String model = 'glm-5.2',
    SessionRouteSource source = SessionRouteSource.user,
    String? previousProvider,
    String? reason,
    String? eventId,
    String? providerDisplayName,
    String? previousProviderDisplayName,
  }) => SessionRouteSnapshot(
    sessionId: 'session-1',
    source: source,
    previousProviderInstanceId: previousProvider,
    providerInstanceId: provider,
    model: model,
    reason: reason,
    requestId: null,
    routeRevision: revision,
    updatedAt: DateTime.parse('2026-07-15T10:00:00Z'),
    eventId: eventId,
    previousProviderDisplayName: previousProviderDisplayName,
    providerDisplayName: providerDisplayName,
  );

  test('accepts newer, idempotent replay, and rejects stale/conflicting revisions', () {
    final registry = SessionRouteRegistry();
    expect(registry.apply(route()).disposition, SessionRouteApplyDisposition.applied);
    expect(registry.apply(route()).disposition, SessionRouteApplyDisposition.idempotent);
    expect(
      registry.apply(route(revision: 0)).disposition,
      SessionRouteApplyDisposition.rejectedStaleRevision,
    );
    expect(
      registry.apply(route(provider: 'provider-b')).disposition,
      SessionRouteApplyDisposition.rejectedConflictingRevision,
    );
    expect(
      registry.apply(route(revision: 2, provider: 'provider-b')).disposition,
      SessionRouteApplyDisposition.applied,
    );
  });

  test('enriches a list snapshot with same-revision live auto-failover metadata', () {
    final registry = SessionRouteRegistry();
    registry.apply(route(provider: 'provider-b'));

    final result = registry.apply(
      route(
        provider: 'provider-b',
        source: SessionRouteSource.autoFailover,
        previousProvider: 'provider-a',
        reason: 'provider_rate_limit',
        eventId: 'route-event-1',
      ),
    );

    expect(result.disposition, SessionRouteApplyDisposition.applied);
    expect(result.current.source, SessionRouteSource.autoFailover);
    expect(result.current.eventId, 'route-event-1');
  });

  test('route_updated_at prevents session updated_at changes from conflicting', () {
    final registry = SessionRouteRegistry();
    final first = SessionRouteSnapshot.fromJson({
      'session_id': 'session-1',
      'provider_instance_id': 'provider-a',
      'model': 'exact-model-id',
      'route_revision': 7,
      'route_updated_at': '2026-07-15T10:00:00Z',
      'updated_at': '2026-07-15T11:00:00Z',
    });
    final renamedSession = SessionRouteSnapshot.fromJson({
      'session_id': 'session-1',
      'provider_instance_id': 'provider-a',
      'model': 'exact-model-id',
      'route_revision': 7,
      'route_updated_at': '2026-07-15T10:00:00Z',
      'updated_at': '2026-07-15T12:00:00Z',
    });

    registry.apply(first);
    expect(
      registry.apply(renamedSession).disposition,
      SessionRouteApplyDisposition.idempotent,
    );
  });

  test('auto-failover text includes old/new provider, reason, and exact model', () {
    final snapshot = route(
      provider: 'Z.ai',
      model: 'glm-5.2-exact',
      source: SessionRouteSource.autoFailover,
      previousProvider: 'NVIDIA NIM',
      reason: 'reached_rate_limit',
    );
    expect(
      snapshot.informationalText,
      'Switched automatically from NVIDIA NIM to Z.ai because reached rate limit. Continuing with glm-5.2-exact.',
    );
  });

  test('auto-failover text prefers display names over raw instance ids', () {
    final snapshot = route(
      provider: '1f2e3d4c-instance-uuid',
      model: 'glm-5.2-exact',
      source: SessionRouteSource.autoFailover,
      previousProvider: '9a8b7c6d-instance-uuid',
      reason: 'rate_limit',
      providerDisplayName: 'Z.ai',
      previousProviderDisplayName: 'NVIDIA NIM',
    );
    expect(
      snapshot.informationalText,
      'Switched automatically from NVIDIA NIM to Z.ai because rate limit. Continuing with glm-5.2-exact.',
    );
    expect(snapshot.informationalText, isNot(contains('instance-uuid')));
  });

  test('auto-failover text falls back to instance id without a display name', () {
    final snapshot = route(
      provider: '1f2e3d4c-instance-uuid',
      model: 'glm-5.2-exact',
      source: SessionRouteSource.autoFailover,
      previousProvider: null,
      reason: 'rate_limit',
    );
    expect(
      snapshot.informationalText,
      'Switched automatically from the previous provider to 1f2e3d4c-instance-uuid because rate limit. Continuing with glm-5.2-exact.',
    );
  });
}
