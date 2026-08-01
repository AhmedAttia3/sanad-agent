import 'package:flutter/material.dart';

/// Keeps the current step actions visible in bounded overlays while allowing
/// Settings to retain ownership of its unbounded page scroll.
class ProviderSetupStepScaffold extends StatelessWidget {
  const ProviderSetupStepScaffold({
    required this.body,
    required this.footer,
    super.key,
  });

  final Widget body;
  final Widget footer;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final bodyWithPadding = Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: body,
        );
        if (!constraints.hasBoundedHeight) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [bodyWithPadding, footer],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(child: SingleChildScrollView(child: bodyWithPadding)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(
                  top: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                  ),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: footer,
              ),
            ),
          ],
        );
      },
    );
  }
}
