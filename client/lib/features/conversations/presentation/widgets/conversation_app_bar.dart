import 'package:sanad_client/features/conversations/domain/models/device_workspace.dart';
import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:sanad_client/utils/app_platform.dart';
import 'package:window_manager/window_manager.dart';
import 'sidebar/sidebar_composition.dart';
import 'package:sanad_client/features/conversations/presentation/utils/text_utils.dart';

class ConversationAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? sessionTitle;
  final DeviceWorkspace? workspace;
  final bool isMobile;
  final VoidCallback? onMenuPressed;

  const ConversationAppBar({
    super.key,
    this.sessionTitle,
    this.workspace,
    this.isMobile = false,
    this.onMenuPressed,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final borderRadius = BorderRadius.circular(12);
    Widget mainContent = Container(
      margin: EdgeInsets.only(
        left: AppPlatform.isMacOS ? 4 : 0,
        right: AppPlatform.isMacOS ? 12 : 0,
        top: AppPlatform.isMacOS ? 8 : 0,
      ),
      child: ClipRRect(
        borderRadius: borderRadius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
          child: Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 8,
              left: isMobile ? 4 : 16,
              right: 16,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: borderRadius,
              border: Border.all(color: theme.colorScheme.outline.withValues(alpha: 0.3)),
            ),
            child: isMobile ? _buildMobileLayout(theme) : _buildDesktopLayout(theme),
          ),
        ),
      ),
    );

    if (AppPlatform.isDesktop && !isMobile) {
      mainContent = DragToMoveArea(child: mainContent);
    }

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(
          maxWidth: SidebarBreakpoints.maxConversationWidth,
        ),
        child: mainContent,
      ),
    );
  }

  Widget _buildDesktopLayout(ThemeData theme) {
    final hasWorkspace = workspace != null;
    final titleDirection = TextUtils.getTextDirection(sessionTitle);
    final workspaceDirection = hasWorkspace ? TextUtils.getTextDirection(workspace!.name) : TextDirection.ltr;
    final isRtl = titleDirection == TextDirection.rtl || workspaceDirection == TextDirection.rtl;

    return Row(
      // textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        if (hasWorkspace) ...[
          Flexible(
            child: Text(
              workspace!.name,
              textDirection: workspaceDirection,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '/',
              textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
              style: TextStyle(fontSize: 16, color: theme.colorScheme.onSurfaceVariant),
            ),
          ),
        ],
        Flexible(
          child: Text(
            sessionTitle ?? 'Conversation',
            textDirection: titleDirection,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
            overflow: TextOverflow.ellipsis,
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout(ThemeData theme) {
    final titleDirection = TextUtils.getTextDirection(sessionTitle);
    final workspaceDirection = workspace != null ? TextUtils.getTextDirection(workspace!.name) : TextDirection.ltr;
    final isRtl = titleDirection == TextDirection.rtl || workspaceDirection == TextDirection.rtl;

    return Row(
      textDirection: isRtl ? TextDirection.rtl : TextDirection.ltr,
      children: [
        if (onMenuPressed != null)
          Padding(
            padding: EdgeInsets.only(
              right: isRtl ? 0 : 4,
              left: isRtl ? 4 : 0,
            ),
            child: IconButton(
              icon: Icon(Icons.menu, color: theme.colorScheme.onSurface),
              onPressed: onMenuPressed,
              tooltip: 'Open navigation menu',
            ),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: isRtl ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                sessionTitle ?? 'Conversation',
                textDirection: titleDirection,
                textAlign: titleDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (workspace != null)
                Padding(
                  padding: const EdgeInsets.only(top: 1),
                  child: Text(
                    workspace!.name,
                    textDirection: workspaceDirection,
                    textAlign: workspaceDirection == TextDirection.rtl ? TextAlign.right : TextAlign.left,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(64);
}
