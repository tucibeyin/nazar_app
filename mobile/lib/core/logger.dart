import 'dart:developer' as dev;

import 'package:flutter/foundation.dart';

abstract final class AppLogger {
  static void info(String message, [Object? data]) {
    final msg = data != null ? '$message | $data' : message;
    dev.log(msg, name: 'INFO');
    if (kDebugMode) debugPrint('[INFO] $msg');
  }

  static void warning(String message, [Object? data]) {
    final msg = data != null ? '$message | $data' : message;
    dev.log(msg, name: 'WARN', level: 900);
    if (kDebugMode) debugPrint('[WARN] $msg');
  }

  static void error(String message, [Object? error, StackTrace? stack]) {
    final msg = error != null ? '$message | $error' : message;
    dev.log(msg, name: 'ERROR', level: 1000, error: error, stackTrace: stack);
    debugPrint('[ERROR] $msg');
    if (kDebugMode && stack != null) debugPrintStack(stackTrace: stack);
  }
}
