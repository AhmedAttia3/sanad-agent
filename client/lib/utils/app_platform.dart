import 'package:flutter/foundation.dart';
import 'package:universal_io/io.dart';

class AppPlatform {
  static bool? overrideIsDesktop;
  static bool? overrideIsMobile;

  static bool get isWeb => kIsWeb;

  static bool get isMacOS => !kIsWeb && (Platform.isMacOS || defaultTargetPlatform == TargetPlatform.macOS);
  static bool get isWindows => !kIsWeb && (Platform.isWindows || defaultTargetPlatform == TargetPlatform.windows);
  static bool get isLinux => !kIsWeb && (Platform.isLinux || defaultTargetPlatform == TargetPlatform.linux);
  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isFuchsia => !kIsWeb && Platform.isFuchsia;

  static bool get isDesktop => overrideIsDesktop ?? (isMacOS || isWindows || isLinux);
  static bool get isMobile => overrideIsMobile ?? (isAndroid || isIOS);
  static bool get isDesktopOrWeb => isWeb || isDesktop;

  static String get name {
    if (isWeb) return 'web';
    if (isMacOS) return 'macos';
    if (isWindows) return 'windows';
    if (isLinux) return 'linux';
    if (isAndroid) return 'android';
    if (isIOS) return 'ios';
    if (isFuchsia) return 'fuchsia';
    return 'unknown';
  }
}
