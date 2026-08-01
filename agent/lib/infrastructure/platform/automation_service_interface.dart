import 'dart:async';

abstract class AutomationServiceInterface {
  /// Checks if the process has the required system permissions (accessibility / screen recording).
  Future<bool> checkPermissions();

  /// Requests the required system permissions from the OS.
  Future<bool> requestPermissions();

  /// Takes a screenshot of the main screen and returns the image bytes (JPG/PNG).
  Future<List<int>> takeScreenshot();

  /// Simulates mouse actions: 'click', 'double_click', 'right_click', 'move', or 'scroll'.
  /// Coordinates [x] and [y] are optional for click/move, while [dx] and [dy] are for scroll distances.
  Future<void> simulateMouse({
    required String action,
    int? x,
    int? y,
    int? dx,
    int? dy,
  });

  /// Simulates keyboard actions: 'type' or 'hotkey'.
  /// [text] is typed for 'type' action, [keys] are key strings for 'hotkey' combination.
  Future<void> simulateKeyboard({
    required String action,
    String? text,
    List<String>? keys,
  });
}
