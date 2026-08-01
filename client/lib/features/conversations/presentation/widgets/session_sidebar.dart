import 'package:flutter/material.dart';

import 'sidebar/device_workspace_sidebar.dart';

/// Legacy sidebar widget (Plan 32c transition).
///
/// Gate C0 introduced [DeviceWorkspaceSidebar] as the redesigned sidebar
/// implementation. During the transition (Gate C0 → C1), this legacy entry
/// point forwards to the new widget so existing call sites
/// (HomeScreen, ConversationWorkspaceLayout, drawer) continue to work without
/// changes. Once Gate C1 cutover is complete and all call sites are updated,
/// this file will be removed.
class SessionSidebar extends StatelessWidget {
  final bool isDrawerMode;
  final VoidCallback? onClose;
  final bool showChrome;
  final double? width;

  @visibleForTesting
  static void Function(String deviceId, String sessionId)? debugOnSessionRowBuild;

  const SessionSidebar({
    super.key,
    this.isDrawerMode = false,
    this.onClose,
    this.showChrome = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return DeviceWorkspaceSidebar(
      isDrawerMode: isDrawerMode,
      onClose: onClose,
      showChrome: showChrome,
      width: width,
    );
  }
}
