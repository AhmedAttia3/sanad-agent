import 'dart:async';

import 'package:sanad_client/features/devices/presentation/bloc/device_cubit.dart';
import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';
import 'package:sanad_client/features/auth/infrastructure/auth_service.dart';
import 'package:sanad_client/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sanad_client/features/auth/presentation/bloc/auth_state.dart';
import 'package:sanad_client/infrastructure/socket/sanad_socket_service.dart';
import 'package:sanad_client/features/conversations/data/repositories/conversation_cache_repository.dart';
import 'package:sanad_client/features/conversations/data/persistence/conversation_cache_persistor.dart';
import 'package:sanad_client/features/devices/data/device_inventory_source.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class AppAuthListener extends StatelessWidget {
  final AuthService authService;
  final SanadSocketService socketService;
  final Future<void> Function() syncAuthContext;
  final ConversationCacheRepository conversationCacheRepository;
  final ConversationCachePersistor conversationCachePersistor;
  final GlobalKey<NavigatorState> navigatorKey;
  final Widget child;

  const AppAuthListener({
    super.key,
    required this.authService,
    required this.socketService,
    required this.syncAuthContext,
    required this.conversationCacheRepository,
    required this.conversationCachePersistor,
    required this.navigatorKey,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthCubit, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticated) {
          unawaited(authService.syncExternalSession(state.accessToken));
          unawaited(syncAuthContext());
          socketService.setAccessToken(state.accessToken);
          unawaited(
            socketService
                .connect()
                .then((_) {
                  if (context.mounted) {
                    unawaited(context.read<DeviceCubit>().fetchAgents());
                  }
                })
                .catchError((_) {}),
          );
        } else if (state is AuthUnauthenticated) {
          final cloudDeviceIds = conversationCacheRepository.snapshot.contexts.keys
              .where((deviceId) => deviceId != DeviceInventoryIds.localDevice)
              .toSet();
          conversationCacheRepository.clearCloudUserScope(cloudDeviceIds);
          unawaited(conversationCachePersistor.flush());
          context.read<DeviceConnectionCoordinator>().clearEventDeduplicationState();
          unawaited(context.read<DeviceCubit>().resetForLogout());
          socketService.disconnect();
          socketService.setAccessToken(null);
          unawaited(authService.logout());
          unawaited(syncAuthContext());
        }
      },
      child: child,
    );
  }
}
