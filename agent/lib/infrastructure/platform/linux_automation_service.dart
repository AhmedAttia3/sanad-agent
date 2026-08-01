import 'dart:async';
import 'dart:io';
import 'automation_service_interface.dart';

class LinuxAutomationService implements AutomationServiceInterface {
  bool? _isWayland;

  Future<bool> get _usingWayland async {
    if (_isWayland != null) return _isWayland!;
    final sessionType =
        Platform.environment['XDG_SESSION_TYPE']?.toLowerCase() ?? '';
    _isWayland = sessionType == 'wayland';
    return _isWayland!;
  }

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
      '${tempDir.path}/sanad_screenshot_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );

    if (await _usingWayland) {
      return _takeScreenshotWayland(tempFile);
    }
    return _takeScreenshotX11(tempFile);
  }

  Future<List<int>> _takeScreenshotWayland(File tempFile) async {
    // Try grim (wlroots) first, then gnome-screenshot (GNOME)
    final tools = [
      ('grim', ['-t', 'jpeg', tempFile.path]),
      ('gnome-screenshot', ['-f', tempFile.path]),
    ];

    for (final tool in tools) {
      try {
        final check = await Process.run('which', [tool.$1]);
        if (check.exitCode == 0) {
          final result = await Process.run(tool.$1, tool.$2);
          if (result.exitCode == 0 && tempFile.existsSync()) {
            return await tempFile.readAsBytes();
          }
        }
      } catch (_) {}
    }

    throw Exception(
      'No supported Wayland screenshot tool found. '
      'Install grim (wlroots) or use GNOME (gnome-screenshot).',
    );
  }

  Future<List<int>> _takeScreenshotX11(File tempFile) async {
    final tools = [
      ('maim', [tempFile.path]),
      ('gnome-screenshot', ['-f', tempFile.path]),
      ('scrot', [tempFile.path]),
      ('import', ['-window', 'root', tempFile.path]),
    ];

    for (final tool in tools) {
      try {
        final check = await Process.run('which', [tool.$1]);
        if (check.exitCode == 0) {
          final result = await Process.run(tool.$1, tool.$2);
          if (result.exitCode == 0 && tempFile.existsSync()) {
            return await tempFile.readAsBytes();
          }
        }
      } catch (_) {}
    }

    throw Exception(
      'No supported X11 screenshot tool found. '
      'Install maim, scrot, gnome-screenshot, or ImageMagick.',
    );
  }

  @override
  Future<void> simulateMouse({
    required String action,
    int? x,
    int? y,
    int? dx,
    int? dy,
  }) async {
    if (await _usingWayland) {
      return _simulateMouseWayland(action, x, y, dx, dy);
    }
    return _simulateMouseX11(action, x, y, dx, dy);
  }

  Future<void> _simulateMouseWayland(
    String action,
    int? x,
    int? y,
    int? dx,
    int? dy,
  ) async {
    final check = await Process.run('which', ['ydotool']);
    if (check.exitCode != 0) {
      throw Exception(
        'ydotool is not installed. Run: sudo apt install ydotool',
      );
    }

    switch (action) {
      case 'move':
        if (x != null && y != null) {
          await Process.run('ydotool', [
            'mousemove',
            x.toString(),
            y.toString(),
          ]);
        }
        break;

      case 'click':
        await Process.run('ydotool', ['click', '0xC0']); // left button
        break;

      case 'double_click':
        await Process.run('ydotool', ['click', '0xC0']);
        await Future.delayed(const Duration(milliseconds: 100));
        await Process.run('ydotool', ['click', '0xC0']);
        break;

      case 'right_click':
        await Process.run('ydotool', ['click', '0xC1']); // right button
        break;

      case 'scroll':
        final amount = dy ?? 1;
        // ydotool scroll takes positive = down, negative = up
        await Process.run('ydotool', ['scroll', amount.toString()]);
        break;

      default:
        throw UnsupportedError('Unsupported mouse action: $action');
    }
  }

  Future<void> _simulateMouseX11(
    String action,
    int? x,
    int? y,
    int? dx,
    int? dy,
  ) async {
    final check = await Process.run('which', ['xdotool']);
    if (check.exitCode != 0) {
      throw Exception(
        'xdotool is not installed. Run: sudo apt install xdotool',
      );
    }

    if (x != null && y != null) {
      await Process.run('xdotool', ['mousemove', x.toString(), y.toString()]);
    }

    switch (action) {
      case 'move':
        break;

      case 'click':
        await Process.run('xdotool', ['click', '1']);
        break;

      case 'double_click':
        await Process.run('xdotool', [
          'click',
          '--repeat',
          '2',
          '--delay',
          '100',
          '1',
        ]);
        break;

      case 'right_click':
        await Process.run('xdotool', ['click', '3']);
        break;

      case 'scroll':
        final amount = dy ?? 1;
        final button = amount > 0 ? '4' : '5';
        for (var i = 0; i < amount.abs(); i++) {
          await Process.run('xdotool', ['click', button]);
        }
        break;

      default:
        throw UnsupportedError('Unsupported mouse action: $action');
    }
  }

  @override
  Future<void> simulateKeyboard({
    required String action,
    String? text,
    List<String>? keys,
  }) async {
    if (await _usingWayland) {
      return _simulateKeyboardWayland(action, text, keys);
    }
    return _simulateKeyboardX11(action, text, keys);
  }

  Future<void> _simulateKeyboardWayland(
    String action,
    String? text,
    List<String>? keys,
  ) async {
    final check = await Process.run('which', ['ydotool']);
    if (check.exitCode != 0) {
      throw Exception(
        'ydotool is not installed. Run: sudo apt install ydotool',
      );
    }

    switch (action) {
      case 'type':
        if (text == null || text.isEmpty) return;
        await Process.run('ydotool', ['type', text]);
        break;

      case 'hotkey':
        if (keys == null || keys.isEmpty) return;
        final combo = keys.map((k) => _waylandKeyCode(k)).join('+');
        await Process.run('ydotool', ['key', combo]);
        break;

      default:
        throw UnsupportedError('Unsupported keyboard action: $action');
    }
  }

  Future<void> _simulateKeyboardX11(
    String action,
    String? text,
    List<String>? keys,
  ) async {
    final check = await Process.run('which', ['xdotool']);
    if (check.exitCode != 0) {
      throw Exception(
        'xdotool is not installed. Run: sudo apt install xdotool',
      );
    }

    switch (action) {
      case 'type':
        if (text == null || text.isEmpty) return;
        await Process.run('xdotool', ['type', text]);
        break;

      case 'hotkey':
        if (keys == null || keys.isEmpty) return;
        final combo = keys.join('+').toLowerCase();
        await Process.run('xdotool', ['key', combo]);
        break;

      default:
        throw UnsupportedError('Unsupported keyboard action: $action');
    }
  }

  String _waylandKeyCode(String key) {
    final lower = key.toLowerCase().trim();
    const keyMap = <String, String>{
      'ctrl': '29',
      'control': '29',
      'shift': '42',
      'alt': '56',
      'option': '56',
      'win': '125',
      'windows': '125',
      'cmd': '125',
      'command': '125',
      'super': '125',
      'enter': '28',
      'return': '28',
      'space': '57',
      'backspace': '14',
      'tab': '15',
      'escape': '1',
      'esc': '1',
      'up': '103',
      'down': '108',
      'left': '105',
      'right': '106',
    };
    return keyMap[lower] ?? lower;
  }
}
