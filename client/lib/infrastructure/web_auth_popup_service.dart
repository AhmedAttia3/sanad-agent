import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'js_interop/auth_popup.dart' as js;

/// Service for handling popup-based authentication on web platform
class WebAuthPopupService {
  static final _logger = Logger('WebAuthPopupService');
  static WebAuthPopupService? _instance;

  WebAuthPopupService._();

  static WebAuthPopupService get instance {
    _instance ??= WebAuthPopupService._();
    return _instance!;
  }

  /// Opens a popup window for OAuth authentication
  /// Returns true if the popup was successfully opened, false if blocked
  bool openAuthPopup(String authUrl) {
    if (!kIsWeb) {
      throw StateError('WebAuthPopupService is only available on web platform');
    }
    _logger.info('Opening auth popup: $authUrl');
    final win = js.openPopup(authUrl, 'SanadAuthPopup', '');
    return win != null;
  }

  /// Checks if the popup window is closed
  bool get isPopupClosed {
    if (!kIsWeb) return true;
    try {
      return js.isPopupClosed();
    } catch (e) {
      _logger.warning('Failed to check if popup is closed: $e');
      return false; // Assume open to avoid premature cancellation
    }
  }

  /// Closes the popup window
  void closePopup() {
    if (!kIsWeb) return;
    try {
      js.closePopup();
    } catch (e) {
      _logger.warning('Failed to close popup: $e');
    }
  }

  void dispose() {
    closePopup();
  }
}
