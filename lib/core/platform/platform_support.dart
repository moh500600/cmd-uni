import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;

/// Which native features exist where the app is running.
///
/// Android/iOS keep every feature. Desktop builds (Windows/Linux/macOS) swap
/// mobile-only plugins for desktop equivalents or switch the feature off with
/// a clear message, so no plugin call can crash with MissingPluginException.
class PlatformSupport {
  PlatformSupport._();

  static bool get isAndroid => !kIsWeb && Platform.isAndroid;
  static bool get isIOS => !kIsWeb && Platform.isIOS;
  static bool get isMobile => isAndroid || isIOS;
  static bool get isWindows => !kIsWeb && Platform.isWindows;
  static bool get isLinux => !kIsWeb && Platform.isLinux;
  static bool get isMacOS => !kIsWeb && Platform.isMacOS;
  static bool get isDesktop => isWindows || isLinux || isMacOS;

  /// Fingerprint / face unlock (mobile) or Windows Hello. Linux has no
  /// backend, so the app lock falls back to the PIN there.
  static bool get biometrics => isMobile || isWindows || isMacOS;

  /// Voice input (speech_to_text) — mobile only in this version.
  static bool get speechToText => isMobile;

  /// Taking a photo with the camera — mobile only. Desktop picks image files.
  static bool get camera => isMobile;

  /// System share sheet that can carry files. On Windows/Linux the app
  /// offers "Save as…" instead.
  static bool get shareFiles => isMobile || isMacOS;

  /// Scheduled (future) notifications. Windows shows one-shot scheduled
  /// toasts; Linux can only show immediate notifications.
  static bool get scheduledNotifications => isMobile || isMacOS || isWindows;

  /// Repeating notifications (daily/weekly…) handled by the OS.
  static bool get repeatingNotifications => isMobile || isMacOS;
}
