// ignore_for_file: constant_identifier_names
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

import 'automation_service_interface.dart';

// Struct for CGPoint
final class CGPoint extends Struct {
  @Double()
  external double x;
  @Double()
  external double y;
}

class MacosAutomationService implements AutomationServiceInterface {
  static final DynamicLibrary _coreGraphics = DynamicLibrary.open(
    '/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics',
  );
  static final DynamicLibrary _applicationServices = DynamicLibrary.open(
    '/System/Library/Frameworks/ApplicationServices.framework/ApplicationServices',
  );

  // CoreFoundation for CFDictionary creation
  static final DynamicLibrary _coreFoundation = DynamicLibrary.open(
    '/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation',
  );

  // FFI Lookups
  static final _axIsProcessTrusted = _applicationServices
      .lookupFunction<Uint8 Function(), int Function()>('AXIsProcessTrusted');

  static final _axIsProcessTrustedWithOptions = _applicationServices
      .lookupFunction<
        Uint8 Function(Pointer<Void>),
        int Function(Pointer<Void>)
      >('AXIsProcessTrustedWithOptions');

  // kAXTrustedCheckOptionPrompt is a CFStringRef global constant in ApplicationServices
  static final Pointer<Pointer<Void>> _kAXTrustedCheckOptionPrompt =
      _applicationServices.lookup<Pointer<Void>>('kAXTrustedCheckOptionPrompt');

  // kCFBooleanTrue is a CFBooleanRef global constant in CoreFoundation
  static final Pointer<Pointer<Void>> _kCFBooleanTrue = _coreFoundation
      .lookup<Pointer<Void>>('kCFBooleanTrue');

  static final _cfDictionaryCreate = _coreFoundation
      .lookupFunction<
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Void>>,
          Int64,
          Pointer<Void>,
          Pointer<Void>,
        ),
        Pointer<Void> Function(
          Pointer<Void>,
          Pointer<Pointer<Void>>,
          Pointer<Pointer<Void>>,
          int,
          Pointer<Void>,
          Pointer<Void>,
        )
      >('CFDictionaryCreate');

  // Screen recording permissions (Catalina+)
  static final _cgPreflightScreenCaptureAccess = _coreGraphics
      .lookupFunction<Bool Function(), bool Function()>(
        'CGPreflightScreenCaptureAccess',
      );

  static final _cgRequestScreenCaptureAccess = _coreGraphics
      .lookupFunction<Bool Function(), bool Function()>(
        'CGRequestScreenCaptureAccess',
      );

  // Event creation
  static final _cgEventCreateMouseEvent = _coreGraphics
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32, CGPoint, Int32),
        Pointer<Void> Function(Pointer<Void>, int, CGPoint, int)
      >('CGEventCreateMouseEvent');

  static final _cgEventCreateKeyboardEvent = _coreGraphics
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Uint16, Bool),
        Pointer<Void> Function(Pointer<Void>, int, bool)
      >('CGEventCreateKeyboardEvent');

  static final _cgEventCreateScrollWheelEvent = _coreGraphics
      .lookupFunction<
        Pointer<Void> Function(Pointer<Void>, Int32, Uint32, Int32),
        Pointer<Void> Function(Pointer<Void>, int, int, int)
      >('CGEventCreateScrollWheelEvent');

  static final _cgEventPost = _coreGraphics
      .lookupFunction<
        Void Function(Int32, Pointer<Void>),
        void Function(int, Pointer<Void>)
      >('CGEventPost');

  static final _cfRelease = _coreGraphics
      .lookupFunction<
        Void Function(Pointer<Void>),
        void Function(Pointer<Void>)
      >('CFRelease');

  static final _cgEventSetIntegerValueField = _coreGraphics
      .lookupFunction<
        Void Function(Pointer<Void>, Int32, Int64),
        void Function(Pointer<Void>, int, int)
      >('CGEventSetIntegerValueField');

  static final _cgEventKeyboardSetUnicodeString = _coreGraphics
      .lookupFunction<
        Void Function(Pointer<Void>, IntPtr, Pointer<Uint16>),
        void Function(Pointer<Void>, int, Pointer<Uint16>)
      >('CGEventKeyboardSetUnicodeString');

  // Constants
  static const int kCGHIDEventTap = 0;

  // Mouse types
  static const int kCGEventLeftMouseDown = 1;
  static const int kCGEventLeftMouseUp = 2;
  static const int kCGEventRightMouseDown = 3;
  static const int kCGEventRightMouseUp = 4;
  static const int kCGEventMouseMoved = 5;
  static const int kCGEventLeftMouseDragged = 6;
  static const int kCGEventRightMouseDragged = 7;
  static const int kCGEventScrollWheel = 22;

  // Mouse buttons
  static const int kCGMouseButtonLeft = 0;
  static const int kCGMouseButtonRight = 1;
  static const int kCGMouseButtonCenter = 2;

  // Scroll units
  static const int kCGScrollEventUnitPixel = 0;
  static const int kCGScrollEventUnitLine = 1;

  // Event fields
  static const int kCGMouseEventClickState = 1;

  @override
  Future<bool> checkPermissions() async {
    final accessibility = _axIsProcessTrusted() != 0;
    final screenRecording = _cgPreflightScreenCaptureAccess();
    return accessibility && screenRecording;
  }

  @override
  Future<bool> requestPermissions() async {
    // Request accessibility with proper CFDictionary prompt
    _requestAccessibilityWithPrompt();

    // Request screen recording (will trigger OS dialog if not allowed)
    final screenGranted = _cgRequestScreenCaptureAccess();

    // Re-check trusted status
    final accessibilityGranted = _axIsProcessTrusted() != 0;
    return accessibilityGranted && screenGranted;
  }

  void _requestAccessibilityWithPrompt() {
    final key = _kAXTrustedCheckOptionPrompt.value;
    final value = _kCFBooleanTrue.value;

    final keys = calloc<Pointer<Void>>(1);
    final values = calloc<Pointer<Void>>(1);
    keys[0] = key;
    values[0] = value;

    final dict = _cfDictionaryCreate(
      nullptr,
      keys,
      values,
      1,
      nullptr,
      nullptr,
    );

    if (dict != nullptr) {
      _axIsProcessTrustedWithOptions(dict);
      _cfRelease(dict);
    }

    calloc.free(keys);
    calloc.free(values);
  }

  @override
  Future<List<int>> takeScreenshot() async {
    // We invoke macOS screencapture CLI tool. It is native and highly optimized.
    // Screencapture automatically triggers system permission dialogs if not allowed.
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}/sanad_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    try {
      final result = await Process.run('screencapture', [
        '-x',
        '-t',
        'jpg',
        tempFile.path,
      ]);
      if (result.exitCode != 0) {
        throw Exception('screencapture failed: ${result.stderr}');
      }

      if (!tempFile.existsSync()) {
        throw Exception('Screenshot file not created.');
      }

      final bytes = await tempFile.readAsBytes();
      return bytes;
    } finally {
      if (tempFile.existsSync()) {
        try {
          tempFile.deleteSync();
        } catch (_) {}
      }
    }
  }

  @override
  Future<void> simulateMouse({
    required String action,
    int? x,
    int? y,
    int? dx,
    int? dy,
  }) async {
    final pos = calloc<CGPoint>();
    pos.ref.x = (x ?? 0).toDouble();
    pos.ref.y = (y ?? 0).toDouble();

    try {
      switch (action) {
        case 'move':
          final event = _cgEventCreateMouseEvent(
            nullptr,
            kCGEventMouseMoved,
            pos.ref,
            kCGMouseButtonLeft,
          );
          if (event != nullptr) {
            _cgEventPost(kCGHIDEventTap, event);
            _cfRelease(event);
          }
          break;

        case 'click':
          _postClick(
            pos.ref,
            kCGMouseButtonLeft,
            kCGEventLeftMouseDown,
            kCGEventLeftMouseUp,
            1,
          );
          break;

        case 'double_click':
          _postClick(
            pos.ref,
            kCGMouseButtonLeft,
            kCGEventLeftMouseDown,
            kCGEventLeftMouseUp,
            2,
          );
          break;

        case 'right_click':
          _postClick(
            pos.ref,
            kCGMouseButtonRight,
            kCGEventRightMouseDown,
            kCGEventRightMouseUp,
            1,
          );
          break;

        case 'scroll':
          // dx/dy are scroll amounts. In macOS, dy is vertical scroll.
          final scrollAmount = dy ?? 0;
          final event = _cgEventCreateScrollWheelEvent(
            nullptr,
            kCGScrollEventUnitLine,
            1,
            scrollAmount,
          );
          if (event != nullptr) {
            _cgEventPost(kCGHIDEventTap, event);
            _cfRelease(event);
          }
          break;

        default:
          throw UnsupportedError('Unsupported mouse action: $action');
      }
    } finally {
      calloc.free(pos);
    }
  }

  void _postClick(
    CGPoint pos,
    int button,
    int downType,
    int upType,
    int clickCount,
  ) {
    final eventDown = _cgEventCreateMouseEvent(nullptr, downType, pos, button);
    if (eventDown != nullptr) {
      if (clickCount > 1) {
        _cgEventSetIntegerValueField(
          eventDown,
          kCGMouseEventClickState,
          clickCount,
        );
      }
      _cgEventPost(kCGHIDEventTap, eventDown);
      _cfRelease(eventDown);
    }

    // Small delay between mouse down and up to simulate realistic click
    sleep(const Duration(milliseconds: 50));

    final eventUp = _cgEventCreateMouseEvent(nullptr, upType, pos, button);
    if (eventUp != nullptr) {
      if (clickCount > 1) {
        _cgEventSetIntegerValueField(
          eventUp,
          kCGMouseEventClickState,
          clickCount,
        );
      }
      _cgEventPost(kCGHIDEventTap, eventUp);
      _cfRelease(eventUp);
    }
  }

  @override
  Future<void> simulateKeyboard({
    required String action,
    String? text,
    List<String>? keys,
  }) async {
    switch (action) {
      case 'type':
        if (text == null || text.isEmpty) return;
        _typeString(text);
        break;

      case 'hotkey':
        if (keys == null || keys.isEmpty) return;
        _pressHotkeys(keys);
        break;

      default:
        throw UnsupportedError('Unsupported keyboard action: $action');
    }
  }

  void _typeString(String text) {
    // Create a dummy key event (keycode 0) and attach the unicode string to it
    final eventDown = _cgEventCreateKeyboardEvent(nullptr, 0, true);
    if (eventDown != nullptr) {
      final units = text.codeUnits;
      final ptr = calloc<Uint16>(units.length);
      for (var i = 0; i < units.length; i++) {
        ptr[i] = units[i];
      }

      _cgEventKeyboardSetUnicodeString(eventDown, units.length, ptr);
      _cgEventPost(kCGHIDEventTap, eventDown);

      _cfRelease(eventDown);
      calloc.free(ptr);
    }
  }

  void _pressHotkeys(List<String> keys) {
    final keyCodes = keys.map(_mapStringToKeyCode).toList();
    final pressedEvents = <Pointer<Void>>[];

    // Press modifier and normal keys down in sequence
    for (final code in keyCodes) {
      if (code != null) {
        final event = _cgEventCreateKeyboardEvent(nullptr, code, true);
        if (event != nullptr) {
          _cgEventPost(kCGHIDEventTap, event);
          pressedEvents.add(event);
        }
      }
      sleep(const Duration(milliseconds: 10));
    }

    // Release them in reverse order
    for (final event in pressedEvents.reversed) {
      final code = keyCodes[pressedEvents.indexOf(event)]!;
      final eventUp = _cgEventCreateKeyboardEvent(nullptr, code, false);
      if (eventUp != nullptr) {
        _cgEventPost(kCGHIDEventTap, eventUp);
        _cfRelease(eventUp);
      }
      _cfRelease(event);
      sleep(const Duration(milliseconds: 10));
    }
  }

  int? _mapStringToKeyCode(String key) {
    final lower = key.toLowerCase().trim();
    switch (lower) {
      case 'ctrl':
      case 'control':
        return 59;
      case 'shift':
        return 56;
      case 'alt':
      case 'option':
        return 58;
      case 'cmd':
      case 'command':
        return 55;
      case 'enter':
      case 'return':
        return 36;
      case 'space':
        return 49;
      case 'backspace':
        return 51;
      case 'tab':
        return 48;
      case 'escape':
      case 'esc':
        return 53;
      case 'up':
        return 126;
      case 'down':
        return 125;
      case 'left':
        return 123;
      case 'right':
        return 124;

      // Basic letters
      case 'a':
        return 0;
      case 's':
        return 1;
      case 'd':
        return 2;
      case 'f':
        return 3;
      case 'h':
        return 4;
      case 'g':
        return 5;
      case 'z':
        return 6;
      case 'x':
        return 7;
      case 'c':
        return 8;
      case 'v':
        return 9;
      case 'b':
        return 11;
      case 'q':
        return 12;
      case 'w':
        return 13;
      case 'e':
        return 14;
      case 'r':
        return 15;
      case 'y':
        return 16;
      case 't':
        return 17;
      case 'o':
        return 31;
      case 'u':
        return 32;
      case 'i':
        return 34;
      case 'p':
        return 35;
      case 'l':
        return 37;
      case 'j':
        return 38;
      case 'k':
        return 40;
      case 'n':
        return 45;
      case 'm':
        return 46;

      default:
        // Try parsing single characters
        if (lower.length == 1) {
          final charCode = lower.codeUnitAt(0);
          if (charCode >= 48 && charCode <= 57) {
            // Numbers 0-9
            const numberMap = [29, 18, 19, 20, 21, 23, 22, 26, 28, 25];
            return numberMap[charCode - 48];
          }
        }
        return null;
    }
  }
}
