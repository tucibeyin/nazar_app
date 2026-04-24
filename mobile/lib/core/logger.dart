import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String message, [Object? data]) {
    if (kDebugMode) debugPrint('[INFO] $message${data != null ? ' | $data' : ''}');
  }

  static void warning(String message, [Object? data]) {
    if (kDebugMode) debugPrint('[WARN] $message${data != null ? ' | $data' : ''}');
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    debugPrint('[ERROR] $message${error != null ? ' | $error' : ''}');
    if (kDebugMode && stack != null) debugPrintStack(stackTrace: stack);
  }
}
