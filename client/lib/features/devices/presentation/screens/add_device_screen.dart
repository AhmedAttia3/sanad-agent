import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:sanad_client/core/navigation/app_routes.dart';
import 'package:sanad_client/features/devices/domain/models/gateway_connection_status.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_cubit.dart';
import 'package:sanad_client/features/devices/presentation/bloc/device_state.dart';
import 'package:sanad_client/features/devices/presentation/bloc/gateway_connection_cubit.dart';
import 'package:sanad_client/features/devices/presentation/widgets/device_install_guide.dart';
import 'package:sanad_client/features/devices/presentation/widgets/gateway_connection_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanad_client/utils/toast_utils.dart';

class AddDeviceScreen extends StatefulWidget {
  const AddDeviceScreen({super.key});

  @override
  State<AddDeviceScreen> createState() => _AddDeviceScreenState();
}

class _AddDeviceScreenState extends State<AddDeviceScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();

  String? _generatedToken;
  String? _createdDeviceId;
  String? _createdDeviceName;
  bool _isCreating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _createDevice(GatewayConnectionStatus gatewayStatus) {
    if (!_formKey.currentState!.validate()) return;
    if (!gatewayStatus.isCloudReady) {
      setState(() {
        _error = 'Connect to SanadGateway before creating a remote device.';
      });
      return;
    }

    final deviceCubit = context.read<DeviceCubit>();
    final deviceName = _nameController.text.trim();

    setState(() {
      _isCreating = true;
      _error = null;
      _generatedToken = null;
      _createdDeviceId = null;
      _createdDeviceName = deviceName;
    });

    deviceCubit.createAgent(deviceName, type: 'computer');
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<DeviceCubit, DeviceState>(
      listener: _handleDeviceStateChange,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text('Add Host Device', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
          leading: IconButton(
            icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
            onPressed: () => Navigator.pop(context),
          ),
          actions: const [
            Padding(
              padding: EdgeInsets.only(right: 12),
              child: Center(child: GatewayConnectionIndicator()),
            ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Icon(Icons.smart_toy_outlined, size: 64, color: Theme.of(context).colorScheme.primary),
                ),
                const SizedBox(height: 18),
                Text(
                  _generatedToken == null ? 'Create a remote host device' : 'Install and connect your device',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  _generatedToken == null
                      ? 'Create a device record, then run the generated install command on your computer or server.'
                      : 'Run one of these commands on the target machine. Sanad will continue automatically when it connects.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                ),
                const SizedBox(height: 32),
                if (_generatedToken == null) ...[
                  TextFormField(
                    controller: _nameController,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      labelText: 'Device Name',
                      labelStyle: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                      border: const OutlineInputBorder(),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.24)),
                      ),
                      prefixIcon: Icon(Icons.label_outline, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter a name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  if (_error != null) _ErrorMessage(message: _error!),
                  BlocBuilder<GatewayConnectionCubit, GatewayConnectionStatus>(
                    builder: (context, gatewayStatus) {
                      return ElevatedButton(
                        onPressed: _isCreating ? null : () => _createDevice(gatewayStatus),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).colorScheme.primary,
                          foregroundColor: Theme.of(context).colorScheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isCreating
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                ),
                              )
                            : Text(
                                'Create Host Device',
                                style: TextStyle(color: Theme.of(context).colorScheme.onPrimary, fontSize: 16),
                              ),
                      );
                    },
                  ),
                ] else ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Device Created Successfully',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        DeviceInstallGuide(token: _generatedToken!),
                        const SizedBox(height: 8),
                        Text(
                          'Waiting for the device to come online...',
                          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: () => context.go(AppRoutes.home),
                          icon: const Icon(Icons.arrow_forward),
                          label: const Text('Continue to Home'),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handleDeviceStateChange(BuildContext context, DeviceState state) {
    final devices = state is DeviceActive ? state.agents : (state is DeviceNoActive ? state.agents : const []);
    final createdName = _createdDeviceName;

    if (_isCreating && createdName != null && devices.isNotEmpty) {
      final matches = devices.where((device) => device.name == createdName && device.token != null);
      if (matches.isNotEmpty) {
        final device = matches.last;
        setState(() {
          _isCreating = false;
          _generatedToken = device.token;
          _createdDeviceId = device.id;
        });
      }
    }

    final createdDeviceId = _createdDeviceId;
    if (createdDeviceId != null) {
      final createdMatches = devices.where((device) => device.id == createdDeviceId && device.isOnline);
      if (createdMatches.isNotEmpty) {
        unawaited(HapticFeedback.lightImpact());
        ToastUtils.showSuccess(context, '${createdMatches.first.name} is connected');
        context.go(AppRoutes.home);
      }
    }
  }
}

class _ErrorMessage extends StatelessWidget {
  final String message;

  const _ErrorMessage({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        ],
      ),
    );
  }
}
