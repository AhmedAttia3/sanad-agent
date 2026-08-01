import 'package:flutter/material.dart';

class AppColorScheme {
  static const ColorScheme light = ColorScheme(
    brightness: Brightness.light,
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF0A0A0A),
    primaryContainer: Color(0xFFE8E8EA),
    onPrimaryContainer: Color(0xFF0A0A0A),
    secondary: Color(0xFF03DAC6),
    onSecondary: Colors.black,
    error: Color(0xFFB00020),
    onError: Colors.white,
    surface: Color(0xFFF4F4F5),
    onSurface: Color(0xFF0A0A0A),
    outline: Color(0xFFE4E4E7),
    surfaceContainer: Color(0xFFE8E8EA),
    surfaceContainerHigh: Color(0xFFDEDEE0),
    surfaceContainerHighest: Color(0xFFDFDFE1),
  );

  static const ColorScheme dark = ColorScheme(
    brightness: Brightness.dark,
    primary: Color(0xFF60A5FA),
    onPrimary: Color(0xFF0A0A0A),
    primaryContainer: Color(0xFF252525),
    onPrimaryContainer: Colors.white,
    secondary: Color(0xFF03DAC6),
    onSecondary: Colors.black,
    error: Color(0xFFCF6679),
    onError: Colors.black,
    surface: Color(0xFF171717), // Sidebar color
    onSurface: Colors.white,
    onSurfaceVariant: Colors.white70,
    outline: Color(0xFF2D2D2D), // Border color
    surfaceContainer: Color(0xFF252525), // Selected/Hover color
  );
}

extension AppColorSchemeX on ColorScheme {
  Color get codeColor => brightness == Brightness.dark
      ? const Color(0xFFE5C07B) // Warm amber/gold for dark mode
      : const Color(0xFFB58900); // Warm amber/gold for light mode
}
