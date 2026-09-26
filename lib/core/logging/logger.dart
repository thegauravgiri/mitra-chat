import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static void info(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[INFO] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }

  static void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      debugPrint('[WARN] $message');
      if (error != null) debugPrint('  Error: $error');
      if (stackTrace != null) debugPrint('  $stackTrace');
    }
  }

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    debugPrint('[ERROR] $message');
    if (error != null) debugPrint('  Error: $error');
    if (stackTrace != null) debugPrint('  $stackTrace');
  }

  /// Sanitizes any string to prevent leaking bearer tokens or keys.
  static String redact(String input) {
    return input.replaceAll(
      RegExp(r'(Bearer\s+|key=)[A-Za-z0-9_\-\.]{8,}', caseSensitive: false),
      r'$1[REDACTED]',
    );
  }
}
