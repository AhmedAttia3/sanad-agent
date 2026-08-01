import 'package:flutter/widgets.dart';

class RebuildCounter extends StatelessWidget {
  final VoidCallback onBuild;
  final Widget child;

  const RebuildCounter({
    super.key,
    required this.onBuild,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    onBuild();
    return child;
  }
}
