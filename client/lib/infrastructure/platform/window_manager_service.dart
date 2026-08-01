import 'dart:async';
import 'package:flutter/material.dart';
import 'package:window_manager/window_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
// import 'package:macos_window_utils/macos/ns_window_button_type.dart';
// import 'package:macos_window_utils/window_manipulator.dart';
import 'package:sanad_client/utils/app_platform.dart';

class WindowManagerService with WindowListener {
  static final WindowManagerService _instance = WindowManagerService._();
  WindowManagerService._();

  static bool _isInitialized = false;
  static Timer? _saveTimer;

  static Future<void> initialize() async {
    if (!AppPlatform.isDesktop) return;

    await windowManager.ensureInitialized();
    windowManager.addListener(_instance);

    final prefs = await SharedPreferences.getInstance();

    // Retrieve saved dimensions/position
    final double? savedWidth = prefs.getDouble('window_width');
    final double? savedHeight = prefs.getDouble('window_height');
    final double? savedX = prefs.getDouble('window_x');
    final double? savedY = prefs.getDouble('window_y');
    final bool isMaximized = prefs.getBool('window_is_maximized') ?? false;

    // Use default values if nothing is saved
    final Size windowSize = (savedWidth != null && savedHeight != null)
        ? Size(savedWidth, savedHeight)
        : const Size(1470, 800);

    // Determine if we should center the window
    final bool hasCentered = prefs.getBool('has_centered_window') ?? false;
    final bool shouldCenter = !hasCentered && (savedX == null || savedY == null);

    final WindowOptions windowOptions = WindowOptions(
      size: windowSize,
      center: shouldCenter,
      backgroundColor: Colors.transparent,
      skipTaskbar: false,
      title: 'Sanad',
      titleBarStyle: TitleBarStyle.hidden,
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      if (savedX != null && savedY != null && !isMaximized) {
        await windowManager.setPosition(Offset(savedX, savedY));
      }

      await windowManager.show();
      await windowManager.focus();

      if (isMaximized) {
        await windowManager.maximize();
      }

      if (shouldCenter) {
        await prefs.setBool('has_centered_window', true);
      }

      // Mark as initialized so subsequent events are tracked
      _isInitialized = true;
    });
  }

  // Helper method to save state with a 500ms debounce
  void _saveWindowState() {
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () async {
      if (!_isInitialized) return;

      final isMaximized = await windowManager.isMaximized();
      final prefs = await SharedPreferences.getInstance();

      if (!isMaximized) {
        final size = await windowManager.getSize();
        final pos = await windowManager.getPosition();
        await prefs.setDouble('window_width', size.width);
        await prefs.setDouble('window_height', size.height);
        await prefs.setDouble('window_x', pos.dx);
        await prefs.setDouble('window_y', pos.dy);
      }
    });
  }

  // WindowListener implementation overrides

  @override
  void onWindowResized() {
    if (!_isInitialized) return;
    _saveWindowState();
  }

  @override
  void onWindowMoved() {
    if (!_isInitialized) return;
    _saveWindowState();
  }

  @override
  void onWindowMaximize() async {
    if (!_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('window_is_maximized', true);
  }

  @override
  void onWindowUnmaximize() async {
    if (!_isInitialized) return;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('window_is_maximized', false);
    _saveWindowState();
  }
}
