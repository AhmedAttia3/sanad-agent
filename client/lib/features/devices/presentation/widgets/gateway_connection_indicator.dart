import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sanad_client/core/navigation/app_routes.dart';
import 'package:sanad_client/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sanad_client/features/devices/domain/models/gateway_connection_status.dart';
import 'package:sanad_client/features/devices/presentation/bloc/gateway_connection_cubit.dart';

class GatewayConnectionIndicator extends StatelessWidget {
  const GatewayConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<GatewayConnectionCubit, GatewayConnectionStatus>(
      builder: (context, status) {
        final theme = Theme.of(context);
        final isHealthy = status.isLocalConnected || status.isCloudReady;

        return PopupMenuButton<GatewayConnectionAction>(
          tooltip: 'Gateway connection',
          onSelected: (action) => _handleAction(context, action),
          itemBuilder: (context) => [
            PopupMenuItem<GatewayConnectionAction>(
              enabled: false,
              child: _GatewayStatusRow(
                label: 'LocalGateway',
                value: status.localGateway.displayLabel,
                connected: status.localGateway == LocalGatewayStatus.connected,
              ),
            ),
            PopupMenuItem<GatewayConnectionAction>(
              enabled: false,
              child: _GatewayStatusRow(
                label: 'SanadGateway',
                value: status.sanadGateway.displayLabel,
                connected:
                    status.sanadGateway == SanadGatewayStatus.connected ||
                    status.sanadGateway == SanadGatewayStatus.authenticatedWithDevices,
              ),
            ),
            if (status.actions.isNotEmpty) const PopupMenuDivider(),
            ...status.actions.map(
              (action) => PopupMenuItem<GatewayConnectionAction>(
                value: action,
                child: Text(action.label),
              ),
            ),
          ],
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.18)),
              color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isHealthy ? Icons.hub_outlined : Icons.hub,
                  size: 16,
                  color: isHealthy ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 8),
                Text(
                  'Gateway connection',
                  style: TextStyle(
                    color: theme.colorScheme.onSurface,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Icon(Icons.expand_more, size: 16, color: theme.colorScheme.onSurfaceVariant),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleAction(BuildContext context, GatewayConnectionAction action) {
    switch (action) {
      case GatewayConnectionAction.signIn:
        unawaited(context.read<AuthCubit>().login());
      case GatewayConnectionAction.retryCloud:
        unawaited(context.read<GatewayConnectionCubit>().retryCloudGateway());
      case GatewayConnectionAction.startLocalAgent:
      case GatewayConnectionAction.repairLocalAgent:
        unawaited(context.read<GatewayConnectionCubit>().startLocalGateway());
      case GatewayConnectionAction.restartLocalAgent:
        unawaited(context.read<GatewayConnectionCubit>().restartLocalGateway());
      case GatewayConnectionAction.stopLocalAgent:
        unawaited(context.read<GatewayConnectionCubit>().stopLocalGateway());
      case GatewayConnectionAction.addDevice:
        unawaited(context.push(AppRoutes.addAgent));
    }
  }
}

class _GatewayStatusRow extends StatelessWidget {
  final String label;
  final String value;
  final bool connected;

  const _GatewayStatusRow({
    required this.label,
    required this.value,
    required this.connected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(
          connected ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 16,
          color: connected ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              color: theme.colorScheme.onSurface,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(color: theme.colorScheme.onSurfaceVariant, fontSize: 12),
        ),
      ],
    );
  }
}

extension _GatewayConnectionActionLabel on GatewayConnectionAction {
  String get label {
    return switch (this) {
      GatewayConnectionAction.signIn => 'Sign in',
      GatewayConnectionAction.retryCloud => 'Retry cloud connection',
      GatewayConnectionAction.startLocalAgent => 'Start local agent',
      GatewayConnectionAction.repairLocalAgent => 'Repair local agent',
      GatewayConnectionAction.restartLocalAgent => 'Restart local agent',
      GatewayConnectionAction.stopLocalAgent => 'Stop local agent',
      GatewayConnectionAction.addDevice => 'Add device',
    };
  }
}
