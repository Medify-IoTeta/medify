import 'package:flutter/foundation.dart';

/// Lightweight leveled logging wrapper over [debugPrint].
/// Debug-level messages are dropped outside debug builds; info/warning/error
/// always print (still safe/no-op-ish in release — just visible in device logs).
class AppLogger {
  AppLogger._();

  static void debug(String message, [String tag = 'App']) {
    if (kDebugMode) _log('DEBUG', tag, message);
  }

  static void info(String message, [String tag = 'App']) {
    _log('INFO', tag, message);
  }

  static void warning(String message, [String tag = 'App']) {
    _log('WARN', tag, message);
  }

  static void error(String message, [Object? error, String tag = 'App']) {
    _log('ERROR', tag, error != null ? '$message: $error' : message);
  }

  static void _log(String level, String tag, String message) {
    final ts = DateTime.now().toIso8601String().substring(11, 23);
    debugPrint('[$ts] $level ${tag.padRight(10)} $message');
  }
}
