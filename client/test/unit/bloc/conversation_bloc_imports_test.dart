import 'package:sanad_client/features/conversations/presentation/bloc/session_cubit.dart' as new_session;
import 'package:sanad_client/features/conversations/presentation/bloc/session_messages_cubit.dart' as new_messages;
import 'package:sanad_client/features/conversations/presentation/bloc/session_messages_state.dart' as new_messages;
import 'package:sanad_client/features/conversations/presentation/bloc/session_sidebar_state.dart' as new_sidebar;
import 'package:sanad_client/features/conversations/presentation/bloc/session_state.dart' as new_session;
import 'package:sanad_client/infrastructure/mcp/mcp_server_manager.dart';
import 'package:sanad_client/infrastructure/mcp/mcp_service.dart';
import 'package:sanad_client/infrastructure/mcp/mcp_transport_detector.dart';
import 'package:sanad_client/infrastructure/platform/window_manager_service.dart';
import 'package:sanad_client/infrastructure/socket/event_router.dart';
import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('new conversation bloc imports expose the moved public state types', () {
    final Type movedSessionCubit = new_session.SessionCubit;
    final Type movedMessagesCubit = new_messages.SessionMessagesCubit;
    const sessionState = new_session.SessionState();
    const messageState = new_messages.SessionMessagesState();
    const sidebarState = new_sidebar.SessionSidebarState();

    expect(movedSessionCubit, new_session.SessionCubit);
    expect(movedMessagesCubit, new_messages.SessionMessagesCubit);
    expect(sessionState.selectedSession, isNull);
    expect(messageState.messages, isEmpty);
    expect(sidebarState.activeDeviceId, isNull);
  });

  test('infrastructure imports expose the migrated transport services', () {
    expect(SanadSocketService, isNotNull);
    expect(EventRouter, isNotNull);
    expect(McpService, isNotNull);
    expect(McpServerManager, isNotNull);
    expect(McpTransportDetector, isNotNull);
    expect(WindowManagerService, isNotNull);
  });
}
