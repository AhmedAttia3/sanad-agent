// ignore_for_file: constant_identifier_names, unused_field
import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';
import 'automation_service_interface.dart';

final class _INPUT extends Struct {
  @Uint32()
  external int type;

  @Uint32()
  external int _pad0;

  @Int32()
  external int dx;
  @Int32()
  external int dy;
  @Uint32()
  external int mouseData;
  @Uint32()
  external int dwFlags;
  @Uint32()
  external int time;

  @Uint32()
  external int _pad1;

  @IntPtr()
  external int dwExtraInfo;
}

class WindowsAutomationService implements AutomationServiceInterface {
  static final DynamicLibrary? _user32 = Platform.isWindows
      ? DynamicLibrary.open('user32.dll')
      : null;

  // ── SendInput ──────────────────────────────────────────────────────────
  static const int INPUT_MOUSE = 0;
  static const int INPUT_KEYBOARD = 1;

  static const int MOUSEEVENTF_LEFTDOWN = 0x0002;
  static const int MOUSEEVENTF_LEFTUP = 0x0004;
  static const int MOUSEEVENTF_RIGHTDOWN = 0x0008;
  static const int MOUSEEVENTF_RIGHTUP = 0x0010;
  static const int MOUSEEVENTF_WHEEL = 0x0800;
  static const int MOUSEEVENTF_ABSOLUTE = 0x8000;

  static const int KEYEVENTF_KEYUP = 0x0002;
  static const int KEYEVENTF_UNICODE = 0x0004;

  static final _sendInput = _user32
      ?.lookupFunction<
        Uint32 Function(Uint32, Pointer<_INPUT>, Int32),
        int Function(int, Pointer<_INPUT>, int)
      >('SendInput');

  static final _setCursorPos = _user32
      ?.lookupFunction<Int32 Function(Int32, Int32), int Function(int, int)>(
        'SetCursorPos',
      );

  @override
  Future<bool> checkPermissions() async {
    return true;
  }

  @override
  Future<bool> requestPermissions() async {
    return true;
  }

  @override
  Future<List<int>> takeScreenshot() async {
    final tempDir = Directory.systemTemp;
    final tempFile = File(
      '${tempDir.path}\\sanad_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    final psCommand =
        'Add-Type -AssemblyName System.Windows.Forms; '
        'Add-Type -AssemblyName System.Drawing; '
        '\$screen = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds; '
        '\$bitmap = New-Object System.Drawing.Bitmap \$screen.Width, \$screen.Height; '
        '\$graphic = [System.Drawing.Graphics]::FromImage(\$bitmap); '
        '\$graphic.CopyFromScreen(\$screen.X, \$screen.Y, 0, 0, \$bitmap.Size); '
        '\$bitmap.Save("${tempFile.path}", [System.Drawing.Imaging.ImageFormat]::Jpeg); '
        '\$bitmap.Dispose(); '
        '\$graphic.Dispose();';

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        psCommand,
      ]);
      if (result.exitCode != 0) {
        throw Exception('Windows screenshot failed: ${result.stderr}');
      }
      if (!tempFile.existsSync()) {
        throw Exception('Screenshot file not created.');
      }
      return await tempFile.readAsBytes();
    } finally {
      if (tempFile.existsSync()) tempFile.deleteSync();
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
    if (_user32 == null) return;

    switch (action) {
      case 'move':
        if (x != null && y != null) _setCursorPos!(x, y);
        break;

      case 'click':
        if (x != null && y != null) _setCursorPos!(x, y);
        await Future.delayed(const Duration(milliseconds: 10));
        _sendMouseInput(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP);
        break;

      case 'double_click':
        if (x != null && y != null) _setCursorPos!(x, y);
        await Future.delayed(const Duration(milliseconds: 10));
        _sendMouseInput(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP);
        await Future.delayed(const Duration(milliseconds: 100));
        _sendMouseInput(MOUSEEVENTF_LEFTDOWN | MOUSEEVENTF_LEFTUP);
        break;

      case 'right_click':
        if (x != null && y != null) _setCursorPos!(x, y);
        await Future.delayed(const Duration(milliseconds: 10));
        _sendMouseInput(MOUSEEVENTF_RIGHTDOWN | MOUSEEVENTF_RIGHTUP);
        break;

      case 'scroll':
        _sendMouseInputData(MOUSEEVENTF_WHEEL, (dy ?? 0) * 120);
        break;

      default:
        throw UnsupportedError('Unsupported mouse action: $action');
    }
  }

  void _sendMouseInput(int flags) {
    final input = calloc<_INPUT>();
    input.ref.type = INPUT_MOUSE;
    input.ref.dwFlags = flags;
    _sendInput!(1, input, sizeOf<_INPUT>());
    calloc.free(input);
  }

  void _sendMouseInputData(int flags, int data) {
    final input = calloc<_INPUT>();
    input.ref.type = INPUT_MOUSE;
    input.ref.dwFlags = flags;
    input.ref.mouseData = data;
    _sendInput!(1, input, sizeOf<_INPUT>());
    calloc.free(input);
  }

  @override
  Future<void> simulateKeyboard({
    required String action,
    String? text,
    List<String>? keys,
  }) async {
    if (_user32 == null) return;

    switch (action) {
      case 'type':
        if (text == null || text.isEmpty) return;
        for (final char in text.runes) {
          _sendUnicodeChar(char);
          await Future.delayed(const Duration(milliseconds: 5));
        }
        break;

      case 'hotkey':
        if (keys == null || keys.isEmpty) return;
        final vks = keys.map(_mapStringToVkCode).toList();
        for (final vk in vks) {
          if (vk != null) {
            _sendVkKey(vk, false);
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
        for (final vk in vks.reversed) {
          if (vk != null) {
            _sendVkKey(vk, true);
            await Future.delayed(const Duration(milliseconds: 10));
          }
        }
        break;

      default:
        throw UnsupportedError('Unsupported keyboard action: $action');
    }
  }

  void _sendUnicodeChar(int charCode) {
    final down = calloc<_INPUT>();
    down.ref.type = INPUT_KEYBOARD;
    down.ref.dx = charCode << 16; // wVk=0, wScan=charCode
    down.ref.dy = KEYEVENTF_UNICODE;
    _sendInput!(1, down, sizeOf<_INPUT>());
    calloc.free(down);

    final up = calloc<_INPUT>();
    up.ref.type = INPUT_KEYBOARD;
    up.ref.dx = charCode << 16;
    up.ref.dy = KEYEVENTF_UNICODE | KEYEVENTF_KEYUP;
    _sendInput!(1, up, sizeOf<_INPUT>());
    calloc.free(up);
  }

  void _sendVkKey(int vk, bool keyUp) {
    final input = calloc<_INPUT>();
    input.ref.type = INPUT_KEYBOARD;
    input.ref.dx = vk; // wVk=vk, wScan=0
    input.ref.dy = keyUp ? KEYEVENTF_KEYUP : 0;
    _sendInput!(1, input, sizeOf<_INPUT>());
    calloc.free(input);
  }

  int? _mapStringToVkCode(String key) {
    final lower = key.toLowerCase().trim();
    switch (lower) {
      case 'ctrl':
      case 'control':
        return 0x11;
      case 'shift':
        return 0x10;
      case 'alt':
        return 0x12;
      case 'win':
      case 'windows':
      case 'cmd':
      case 'command':
        return 0x5B;
      case 'enter':
      case 'return':
        return 0x0D;
      case 'space':
        return 0x20;
      case 'backspace':
        return 0x08;
      case 'tab':
        return 0x09;
      case 'escape':
      case 'esc':
        return 0x1B;
      case 'up':
        return 0x26;
      case 'down':
        return 0x28;
      case 'left':
        return 0x25;
      case 'right':
        return 0x27;
      default:
        if (lower.length == 1) {
          final code = lower.codeUnitAt(0);
          if (code >= 97 && code <= 122) return code - 32;
          if (code >= 48 && code <= 57) return code;
        }
        return null;
    }
  }
}
