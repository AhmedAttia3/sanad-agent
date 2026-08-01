// Mock implementation for non-web platforms
// This file provides a no-op implementation for desktop/mobile platforms

class WebAuthPopupService {
  WebAuthPopupService._();

  static WebAuthPopupService? _instance;

  static WebAuthPopupService get instance {
    _instance ??= WebAuthPopupService._();
    return _instance!;
  }

  bool openAuthPopup(String authUrl) {
    throw UnimplementedError('WebAuthPopupService is only available on web platform');
  }

  bool get isPopupClosed => true;

  void closePopup() {
    // No-op for non-web platforms
  }

  void dispose() {
    // No-op for non-web platforms
  }
}
