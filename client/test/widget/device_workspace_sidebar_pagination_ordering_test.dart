import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sanad_client/features/conversations/data/repositories/conversation_cache_repository.dart';
import 'package:sanad_client/features/conversations/domain/models/session.dart';
import 'package:sanad_client/features/conversations/domain/stores/conversation_cache_store.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_cubit.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_sidebar_cubit.dart';
import 'package:sanad_client/features/conversations/presentation/bloc/session_state.dart';
import 'package:sanad_client/features/conversations/presentation/widgets/sidebar/device_workspace_sidebar.dart';
import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';
import 'package:sanad_client/features/devices/domain/models/capability.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/devices/domain/stores/device_capabilities_store.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_capabilities_cubit.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_capabilities_state.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_cubit.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_state.dart';

import '../helpers/fake_conversation_repository.dart';
import '../helpers/fake_device_repository.dart';
import '../helpers/fake_socket.dart';
import '../helpers/pump_app.dart';

/// Device workspace sidebar widget tests for section pagination and live
/// ordering. These tests intentionally use a static capabilities cubit so the
/// widget tree does not start capability-fetch timers in Flutter's FakeAsync
/// test zone.
void main() {
  late FakeSanadSocketService socket;
  late FakeDeviceRepository agentRepository;
  late FakeDeviceClientRegistry agentClientRegistry;
  late TestDeviceCubit agentCubit;
  late DeviceCapabilitiesStore capabilities;
  late _StaticDeviceCapabilitiesCubit capabilitiesCubit;
  late DeviceConnectionCoordinator resolver;
  late FakeConversationRepository conversationRepository;
  late ConversationCacheStore cacheStore;
  late ConversationCacheRepository cacheRepository;
  late _TestSessionCubit sessionCubit;
  late DeviceConfig device;

  setUp(() async {
    socket = FakeSanadSocketService()..setConnected(true);
    agentRepository = FakeDeviceRepository();
    agentClientRegistry = FakeDeviceClientRegistry();
    agentCubit = TestDeviceCubit(
      socketService: socket,
      agentRepository: agentRepository,
      agentClientRegistry: agentClientRegistry,
    );
    resolver = createTestResolver(cloudSocket: socket, localSocket: socket);
    capabilities = DeviceCapabilitiesStore(resolver);
    conversationRepository = FakeConversationRepository();
    device = DeviceConfig(
      id: 'device-1',
      name: 'Sanad Desktop',
      isOnline: true,
      metadata: const {
        'is_local_reachable': true,
        'preferred_connection_scope': 'local',
      },
    );
    agentRepository.seedAgents([device], activeAgentId: device.id);
    agentCubit.emitState(DeviceActive(activeAgent: device, agents: [device]));
    capabilitiesCubit = _StaticDeviceCapabilitiesCubit(
      capabilities: capabilities,
      agentCubit: agentCubit,
      deviceId: device.id,
    );
    sessionCubit = _TestSessionCubit(
      agentCubit: agentCubit,
      socketService: socket,
      conversationRepository: conversationRepository,
    );
    cacheStore = ConversationCacheStore();
    cacheRepository = ConversationCacheRepository(
      cache: cacheStore,
      transport: conversationRepository,
    );
    cacheStore.setActiveDevice(device.id);
  });

  tearDown(() async {
    await sessionCubit.close();
    await capabilitiesCubit.close();
    await agentCubit.close();
    capabilities.dispose();
    resolver.dispose();
    await conversationRepository.dispose();
    socket.dispose();
  });

  Future<void> pumpSidebar(WidgetTester tester, SessionSidebarCubit cubit) {
    return pumpTestApp(
      tester,
      agentCubit: agentCubit,
      sessionCubit: sessionCubit,
      sessionSidebarCubit: cubit,
      deviceCapabilitiesCubit: capabilitiesCubit,
      conversationCacheRepository: cacheRepository,
      conversationRepository: conversationRepository,
      child: const DeviceWorkspaceSidebar(showChrome: false, key: Key('sidebar')),
    );
  }

  testWidgets('renders cached device header without starting capability fetch timers', (tester) async {
    final cubit = SessionSidebarCubit(cacheRepository: cacheRepository);
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });

    await pumpSidebar(tester, cubit);
    await tester.pump();

    expect(find.textContaining('Sanad Desktop'), findsOneWidget);
  });

  testWidgets('load more appends only the unscoped conversations section', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(800, 800);
    addTearDown(() => tester.view.resetDevicePixelRatio());
    addTearDown(() => tester.view.resetPhysicalSize());

    final sessions = List.generate(
      8,
      (i) => _session(
        id: 'session-$i',
        title: 'Session $i',
        lastMessageAt: DateTime(2026, 1, 8).subtract(Duration(hours: i)),
      ),
    );
    conversationRepository.seedSessions(device, sessions);

    final cubit = SessionSidebarCubit(cacheRepository: cacheRepository);
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
    await cubit.loadUnscopedConversationsIfNeeded(device);

    await pumpSidebar(tester, cubit);
    await tester.pump();

    expect(find.text('Session 0'), findsOneWidget);
    expect(find.text('Session 5'), findsOneWidget);
    expect(find.text('Session 6'), findsNothing);
    await tester.ensureVisible(find.text('Load more'));
    await tester.tap(find.text('Load more'));
    await tester.pump();
    await tester.pump();

    expect(find.text('Session 6'), findsOneWidget);
    expect(find.text('Session 7'), findsOneWidget);
  });

  testWidgets('live user message reorders a row while preserving selected session', (tester) async {
    final older = _session(
      id: 'older',
      title: 'Older conversation',
      lastMessageAt: DateTime(2026, 1, 1),
    );
    final newer = _session(
      id: 'newer',
      title: 'Newer conversation',
      lastMessageAt: DateTime(2026, 1, 2),
    );
    conversationRepository.seedSessions(device, [older, newer]);
    sessionCubit.emitState(SessionState(selectedSession: newer));

    final cubit = SessionSidebarCubit(cacheRepository: cacheRepository);
    addTearDown(() async {
      if (!cubit.isClosed) await cubit.close();
    });
    await cubit.loadUnscopedConversationsIfNeeded(device);

    await pumpSidebar(tester, cubit);
    await tester.pump();

    final newerTopBefore = tester.getTopLeft(find.text('Newer conversation')).dy;
    final olderTopBefore = tester.getTopLeft(find.text('Older conversation')).dy;
    expect(newerTopBefore, lessThan(olderTopBefore));

    cacheRepository.applyUserMessageAccepted(
      device.id,
      older.id,
      timestamp: DateTime(2026, 1, 3),
    );
    await tester.pump();

    final olderTopAtAnimationStart = tester.getTopLeft(find.text('Older conversation')).dy;
    expect(olderTopAtAnimationStart, closeTo(olderTopBefore, 0.5));

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    expect(
      tester.getTopLeft(find.text('Older conversation')).dy,
      closeTo(olderTopBefore, 0.5),
    );
    await tester.pump(const Duration(milliseconds: 45));
    final olderTopMidAnimation = tester.getTopLeft(find.text('Older conversation')).dy;
    expect(olderTopMidAnimation, lessThan(olderTopBefore));
    expect(olderTopMidAnimation, greaterThanOrEqualTo(newerTopBefore));

    await tester.pump(const Duration(milliseconds: 220));

    final olderTopAfter = tester.getTopLeft(find.text('Older conversation')).dy;
    final newerTopAfter = tester.getTopLeft(find.text('Newer conversation')).dy;
    expect(olderTopAfter, lessThan(newerTopAfter));
    expect(sessionCubit.state.selectedSession?.id, newer.id);
  });
}

Session _session({
  required String id,
  required String title,
  required DateTime lastMessageAt,
}) {
  return Session(
    id: id,
    title: title,
    deviceId: 'device-1',
    createdAt: lastMessageAt,
    updatedAt: lastMessageAt,
    lastMessageAt: lastMessageAt,
  );
}

class _StaticDeviceCapabilitiesCubit extends Cubit<DeviceCapabilitiesState> implements DeviceCapabilitiesCubit {
  @override
  final DeviceCapabilitiesStore capabilities;

  @override
  final DeviceCubit agentCubit;

  _StaticDeviceCapabilitiesCubit({
    required this.capabilities,
    required this.agentCubit,
    required String deviceId,
  }) : super(
         DeviceCapabilitiesState(
           capabilitiesByAgentId: {deviceId: const Capability()},
         ),
       );

  @override
  Future<void> ensureFreshForAgent(DeviceConfig agent, {bool force = false}) async {}
}

class _TestSessionCubit extends SessionCubit {
  _TestSessionCubit({
    required super.agentCubit,
    required super.socketService,
    required super.conversationRepository,
  });

  void emitState(SessionState state) => emit(state);
}
