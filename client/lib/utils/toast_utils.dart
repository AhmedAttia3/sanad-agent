import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';
import 'package:sanad_client/utils/app_platform.dart';

class ToastUtils {
  static void showError(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.error,
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 2),
      title: Text(message),
      alignment: AppPlatform.isMobile ? Alignment.topCenter : Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      // animationBuilder:
      //     (context, animation, alignment, child) {
      //   return FadeTransition(opacity: animation, child: child);
      // },
      icon: Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
      showIcon: true,
      primaryColor: Theme.of(context).colorScheme.error,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      closeButton: const ToastCloseButton(),
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: true,
    );
  }

  static void showSuccess(BuildContext context, String message) {
    toastification.show(
      context: context,
      type: ToastificationType.success,
      style: ToastificationStyle.flat,
      autoCloseDuration: const Duration(seconds: 2),
      title: Text(message),
      alignment: AppPlatform.isMobile ? Alignment.topCenter : Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      icon: Icon(Icons.check_circle_outline, color: Theme.of(context).colorScheme.primary),
      showIcon: true,
      primaryColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface.withValues(alpha: 0.35),
      foregroundColor: Theme.of(context).colorScheme.onSurface,
      borderSide: BorderSide(
        color: Theme.of(context).colorScheme.outline.withValues(alpha: 0.30),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(12),
      showProgressBar: true,
      closeButton: const ToastCloseButton(),
      closeOnClick: false,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: true,
    );
  }
}
