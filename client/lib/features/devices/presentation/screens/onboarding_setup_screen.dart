import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sanad_client/core/navigation/app_routes.dart';
import 'package:sanad_client/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sanad_client/features/auth/presentation/bloc/auth_state.dart';
import 'package:sanad_client/features/devices/domain/models/device_config.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_cubit.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_state.dart';
import 'package:sanad_client/features/devices/presentation/bloc/gateway_connection_cubit.dart';
import 'package:sanad_client/features/devices/domain/models/gateway_connection_status.dart';
import 'package:flutter/material.dart';
import 'package:sanad_client/features/devices/presentation/widgets/installation_terminal_view.dart';
import 'package:sanad_client/features/devices/presentation/widgets/gateway_connection_indicator.dart';
import 'package:sanad_client/features/provider_setup/data/provider_setup_client.dart';
import 'package:sanad_client/features/provider_setup/presentation/widgets/provider_setup_flow.dart';
import 'package:sanad_client/core/di/injection.dart';
import 'package:sanad_client/features/devices/data/device_connection_coordinator.dart';
import 'package:sanad_client/features/devices/data/device_inventory_source.dart';
import 'package:go_router/go_router.dart';

class OnboardingSetupScreen extends StatefulWidget {
  const OnboardingSetupScreen({super.key});

  @override
  State<OnboardingSetupScreen> createState() => _OnboardingSetupScreenState();
}

class _OnboardingSetupScreenState extends State<OnboardingSetupScreen> {
  bool _showTerminal = false;
  bool _showProviderSetup = false;
  bool _providerChecked = false;
  bool _checkingProvider = false;
  String? _error;
  late final String _targetVersion; // The pinned release version tag

  @override
  void initState() {
    super.initState();
    final expectedVersion = getIt<DeviceConnectionCoordinator>().expectedVersion;
    _targetVersion = 'v$expectedVersion';
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthCubit>().state is AuthAuthenticated) {
        unawaited(_routeAfterCloudAuth());
      }
    });
  }

  void _onInstallSuccess() {
    unawaited(_checkProviderReadiness());
  }

  void _onInstallFailure(String errorMsg) {
    setState(() {
      _error = errorMsg;
      _showTerminal = false;
    });
  }

  /// Plan 19 onboarding gate: a connected local daemon is not enough to enter
  /// home — the agent must also report `provider.runtime_check` ready. When
  /// not ready, the provider setup UI is shown instead of the chat screen.
  Future<void> _checkProviderReadiness() async {
    if (_providerChecked || _checkingProvider) return;
    _checkingProvider = true;
    try {
      final readiness = await getIt<ProviderSetupClient>().runtimeCheck();
      if (!mounted) return;
      _providerChecked = true;
      if (readiness.runtimeReady) {
        context.go(AppRoutes.home);
      } else {
        setState(() => _showProviderSetup = true);
      }
    } catch (_) {
      if (!mounted) return;
      // If the check itself fails, surface the setup UI so the user can retry.
      _providerChecked = true;
      setState(() => _showProviderSetup = true);
    } finally {
      _checkingProvider = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthCubit, AuthState>(
          listener: (context, state) {
            if (state is AuthAuthenticated) {
              unawaited(_routeAfterCloudAuth());
            }
          },
        ),
        BlocListener<GatewayConnectionCubit, GatewayConnectionStatus>(
          listener: (context, status) {
            if (status.isDesktop && status.localGateway == LocalGatewayStatus.connected && !_showProviderSetup) {
              unawaited(_checkProviderReadiness());
            }
          },
        ),
        BlocListener<DeviceCubit, DeviceState>(
          listener: (context, state) {
            final devices = _registeredDevicesFromState(state);
            if (devices.isNotEmpty) {
              context.go(AppRoutes.home);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Center(
          child: Container(
            width: 650,
            constraints: const BoxConstraints(maxHeight: 680),
            padding: const EdgeInsets.all(40),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 30,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: _showProviderSetup
                  ? ProviderSetupFlow(
                      onReady: (_) {
                        if (mounted) context.go(AppRoutes.home);
                      },
                    )
                  : _showTerminal
                  ? InstallationTerminalView(
                      versionTag: _targetVersion,
                      onComplete: _onInstallSuccess,
                      onFailure: _onInstallFailure,
                    )
                  : _buildSelectionView(theme),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionView(ThemeData theme) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Brand Header
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.rocket_launch_outlined,
              size: 44,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Sanad Agent',
              style: TextStyle(
                fontSize: 36,
                fontWeight: FontWeight.bold,
                letterSpacing: -1.0,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'The local agent is currently inactive. Please select your preferred setup mode to start.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 36),
        const Align(
          alignment: Alignment.center,
          child: GatewayConnectionIndicator(),
        ),
        const SizedBox(height: 24),

        // Option A: Local offline mode
        _buildOptionCard(
          theme: theme,
          icon: Icons.computer_outlined,
          title: 'Run Locally (Offline Mode)',
          description: 'Download the local agent and install it as a background service running on your machine.',
          onTap: () {
            setState(() {
              _showTerminal = true;
              _error = null;
            });
          },
        ),
        const SizedBox(height: 16),

        BlocBuilder<AuthCubit, AuthState>(
          builder: (context, authState) {
            return BlocBuilder<DeviceCubit, DeviceState>(
              builder: (context, deviceState) {
                final isAuthenticated = authState is AuthAuthenticated;
                final registeredDevices = _registeredDevicesFromState(deviceState);
                final hasRegisteredDevices = registeredDevices.isNotEmpty;

                return _buildOptionCard(
                  theme: theme,
                  icon: Icons.cloud_outlined,
                  title: isAuthenticated
                      ? (hasRegisteredDevices ? 'Use Existing Cloud Devices' : 'Add Remote Device')
                      : 'Sign in to Connect Remote',
                  description: isAuthenticated
                      ? (hasRegisteredDevices
                            ? 'Continue to your linked computers and servers through SanadGateway.'
                            : 'Create a remote device record, then install Sanad Agent on that machine.')
                      : 'Sign in first, then add or choose a remote computer or server.',
                  onTap: () {
                    if (!isAuthenticated) {
                      unawaited(context.read<AuthCubit>().login());
                      return;
                    }
                    if (hasRegisteredDevices) {
                      context.go(AppRoutes.home);
                    } else {
                      unawaited(context.push(AppRoutes.addAgent));
                    }
                  },
                );
              },
            );
          },
        ),

        if (_error != null) ...[
          const SizedBox(height: 24),
          Text(
            _error!,
            style: const TextStyle(color: Colors.redAccent, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        ],
      ],
    );
  }

  Future<void> _routeAfterCloudAuth() async {
    final deviceCubit = context.read<DeviceCubit>();
    List<DeviceConfig> fetchedDevices = const [];
    try {
      fetchedDevices = await deviceCubit.fetchAgents();
    } catch (_) {}
    if (!mounted) return;

    final state = deviceCubit.state;
    final devices = fetchedDevices.isNotEmpty ? fetchedDevices : _registeredDevicesFromState(state);
    final hasRegisteredDevice = devices.any((device) => device.id != DeviceInventoryIds.localDevice);
    if (hasRegisteredDevice) {
      context.go(AppRoutes.home);
    }
  }

  List<DeviceConfig> _registeredDevicesFromState(DeviceState state) {
    final devices = state is DeviceActive
        ? state.agents
        : (state is DeviceNoActive ? state.agents : const <DeviceConfig>[]);
    return devices.where((device) => device.id != DeviceInventoryIds.localDevice).toList();
  }

  Widget _buildOptionCard({
    required ThemeData theme,
    required IconData icon,
    required String title,
    required String description,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.1),
            ),
            borderRadius: BorderRadius.circular(16),
            color: theme.colorScheme.onSurface.withValues(alpha: 0.02),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: theme.colorScheme.primary, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 13,
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
