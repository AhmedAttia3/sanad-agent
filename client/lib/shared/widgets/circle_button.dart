import 'package:flutter/material.dart';

class CircleButton extends StatelessWidget {
  final IconData? icon;
  final String? assetPath;
  final Color color;
  final Color? iconColor;
  final VoidCallback onPressed;
  final bool useOriginalColor;

  const CircleButton({
    super.key,
    this.icon,
    this.assetPath,
    required this.color,
    this.iconColor,
    required this.onPressed,
    this.useOriginalColor = false,
  });

  @override
  Widget build(BuildContext context) {
    final effectiveIconColor = iconColor ?? Theme.of(context).colorScheme.onSurface;

    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
        ),
        padding: const EdgeInsets.all(12),
        child: assetPath != null
            ? Image.asset(assetPath!, color: useOriginalColor ? null : effectiveIconColor)
            : Icon(icon, color: effectiveIconColor, size: 24),
      ),
    );
  }
}
