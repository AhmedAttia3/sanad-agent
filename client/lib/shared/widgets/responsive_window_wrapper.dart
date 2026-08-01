// import 'package:logging/logging.dart';
import 'package:flutter/material.dart';
import 'package:sanad_client/utils/app_platform.dart';
import 'package:sanad_client/shared/widgets/app_window_title_bar.dart';

class ResponsiveWindowWrapper extends StatelessWidget {
  // static final _logger = Logger('ResponsiveWindowWrapper');

  final Widget? child;

  const ResponsiveWindowWrapper({super.key, this.child});

  @override
  Widget build(BuildContext context) {
    if (child == null) return const SizedBox.shrink();

    final bool showTitleBar = AppPlatform.isWindows || AppPlatform.isLinux;

    // _logger.info('showTitleBar: $showTitleBar');
    if (!showTitleBar) return child!;

    return Material(
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.only(top: showTitleBar ? 32 : 0),
            child: child!,
          ),
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: AppWindowTitleBar(),
          ),
        ],
      ),
    );
  }
}
