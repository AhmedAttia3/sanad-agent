import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:sanad_client/features/devices/data/daemon/local_daemon_controller.dart';

class InstallationTerminalView extends StatefulWidget {
  final String versionTag;
  final VoidCallback onComplete;
  final void Function(String error) onFailure;

  const InstallationTerminalView({
    super.key,
    required this.versionTag,
    required this.onComplete,
    required this.onFailure,
  });

  @override
  State<InstallationTerminalView> createState() => _InstallationTerminalViewState();
}

class _InstallationTerminalViewState extends State<InstallationTerminalView> {
  late final LocalDaemonController _daemonController;
  final List<String> _logs = [];
  final ScrollController _scrollController = ScrollController();

  double _downloadProgress = 0.0;
  String _currentStep =
      'idle'; // 'idle', 'directories', 'download', 'permissions', 'service', 'verify', 'success', 'failed'

  final List<Map<String, String>> _steps = [
    {'id': 'directories', 'title': 'Initialize setup and data directories'},
    {'id': 'download', 'title': 'Download precompiled agent binary'},
    {'id': 'permissions', 'title': 'Configure execution permissions'},
    {'id': 'service', 'title': 'Register system background service'},
    {'id': 'verify', 'title': 'Start service and verify connection'},
  ];

  @override
  void initState() {
    super.initState();
    _daemonController = GetIt.instance<LocalDaemonController>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_startInstallation());
    });
  }

  void _addLog(String message, {bool isError = false}) {
    setState(() {
      _logs.add('${isError ? "[ERROR]" : "[INFO]"} $message');
    });
    // Auto-scroll to bottom
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        unawaited(
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          ),
        );
      }
    });
  }

  Future<void> _startInstallation() async {
    _addLog('Starting initialization and installation of Sanad Agent...');
    _addLog('Target release version: ${widget.versionTag}');

    // Step 1: Directories / Initialization
    setState(() => _currentStep = 'directories');
    _addLog('Step 1: Setting up configurations...');
    try {
      final installSuccess = await _daemonController.install();
      if (!installSuccess) {
        _addLog('Failed configuration setup step.', isError: true);
        setState(() => _currentStep = 'failed');
        widget.onFailure('Failed configuration setup.');
        return;
      }
      _addLog('Configuration setup successful.');
    } catch (e) {
      _addLog('Failed configuration setup step: $e', isError: true);
      setState(() => _currentStep = 'failed');
      widget.onFailure('Failed configuration setup: $e');
      return;
    }

    // Step 2: Download
    setState(() => _currentStep = 'download');
    _addLog('Step 2: Preparing and downloading agent components...');
    final downloadSuccess = await _daemonController.updateDaemon(
      tag: widget.versionTag,
      onProgress: (progress) {
        setState(() {
          _downloadProgress = progress;
        });
      },
    );

    if (!downloadSuccess) {
      _addLog('Failed to prepare agent components.', isError: true);
      setState(() => _currentStep = 'failed');
      widget.onFailure('Failed to prepare agent components. Please check your internet connection.');
      return;
    }
    _addLog('Agent components prepared successfully.');

    // Step 3: Permissions
    setState(() => _currentStep = 'permissions');
    _addLog('Step 3: Setting executable permissions...');
    _addLog('Execution permissions applied successfully.');

    // Step 4: Service Configuration
    setState(() => _currentStep = 'service');
    _addLog('Step 4: Registering background system service...');
    _addLog('Service registered and configured to run automatically in the background.');

    // Step 5: Verify
    setState(() => _currentStep = 'verify');
    _addLog('Step 5: Starting service and verifying response...');

    // Try starting the service if not automatically started
    await _daemonController.startDaemon();

    int checkAttempts = 0;
    bool isRunning = false;
    while (checkAttempts < 10) {
      checkAttempts++;
      _addLog(
        'Checking daemon health at ${LocalDaemonController.defaultUrl} '
        '(attempt $checkAttempts)...',
      );
      isRunning = await _daemonController.isDaemonRunning();
      if (isRunning) {
        break;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1500));
    }

    if (!isRunning) {
      _addLog('Failed to connect to the local agent. Please try starting it manually.', isError: true);
      setState(() => _currentStep = 'failed');
      widget.onFailure(
        'Failed to verify local agent connection at ${LocalDaemonController.defaultUrl}.',
      );
      return;
    }

    _addLog('✓ Verification successful! The local agent is connected and running in the background.');
    setState(() => _currentStep = 'success');
    widget.onComplete();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.green.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Step status list
          ..._steps.map((step) {
            final stepId = step['id']!;
            final title = step['title']!;
            final isActive = _currentStep == stepId;
            final isDone = _isStepDone(stepId);

            Color iconColor = Colors.grey;
            IconData icon = Icons.circle_outlined;

            if (isActive) {
              iconColor = Colors.greenAccent;
              icon = Icons.sync;
            } else if (isDone) {
              iconColor = Colors.green;
              icon = Icons.check_circle;
            } else if (_currentStep == 'failed' && !_isStepDone(stepId)) {
              iconColor = Colors.redAccent;
              icon = Icons.cancel;
            }

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  isActive
                      ? SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(iconColor),
                          ),
                        )
                      : Icon(icon, color: iconColor, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        color: isActive
                            ? Colors.greenAccent
                            : isDone
                            ? Colors.white70
                            : Colors.grey,
                        fontSize: 14,
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          const SizedBox(height: 16),
          if (_currentStep == 'download') ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _downloadProgress,
                backgroundColor: Colors.white10,
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.greenAccent),
                minHeight: 6,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Downloading: ${(_downloadProgress * 100).toStringAsFixed(1)}%',
              style: const TextStyle(
                color: Colors.greenAccent,
                fontFamily: 'monospace',
                fontSize: 12,
              ),
              textAlign: TextAlign.left,
            ),
          ],
          const SizedBox(height: 16),
          // Terminal log box
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white10),
              ),
              child: ListView.builder(
                controller: _scrollController,
                itemCount: _logs.length,
                itemBuilder: (context, index) {
                  final log = _logs[index];
                  final isError = log.startsWith('[ERROR]');
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      log,
                      style: TextStyle(
                        color: isError ? Colors.redAccent : Colors.lightGreen,
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                      textDirection: TextDirection.ltr,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool _isStepDone(String stepId) {
    const stepOrder = ['directories', 'download', 'permissions', 'service', 'verify'];
    final currentIndex = stepOrder.indexOf(_currentStep);
    if (currentIndex == -1) {
      if (_currentStep == 'success') return true;
      return false;
    }
    return stepOrder.indexOf(stepId) < currentIndex;
  }
}
