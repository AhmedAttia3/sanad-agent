import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sanad_client/utils/app_platform.dart';

class MultilineSubmissionShortcuts extends StatelessWidget {
  final Widget child;
  final TextEditingController controller;
  final VoidCallback onSubmit;
  final Map<ShortcutActivator, VoidCallback> additionalDesktopBindings;

  const MultilineSubmissionShortcuts({
    super.key,
    required this.child,
    required this.controller,
    required this.onSubmit,
    this.additionalDesktopBindings = const {},
  });

  void _insertLineBreak() {
    final value = controller.value;
    final selection = value.selection.isValid ? value.selection : TextSelection.collapsed(offset: value.text.length);
    controller.value = value.copyWith(
      text: value.text.replaceRange(selection.start, selection.end, '\n'),
      selection: TextSelection.collapsed(offset: selection.start + 1),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (AppPlatform.isMobile) return child;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(
          LogicalKeyboardKey.enter,
          shift: false,
          includeRepeats: false,
        ): onSubmit,
        const SingleActivator(
          LogicalKeyboardKey.enter,
          shift: true,
          includeRepeats: false,
        ): _insertLineBreak,
        ...additionalDesktopBindings,
      },
      child: child,
    );
  }
}
