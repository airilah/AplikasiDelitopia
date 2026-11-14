import 'dart:async';
import 'package:flutter/foundation.dart';

typedef AppErrorRecorder = FutureOr<void> Function(
  Object error,
  StackTrace? stackTrace, {
  String? reason,
  bool fatal,
});

/// Centralized application error hook for uncaught Flutter and platform errors.
class ErrorReportingService {
  ErrorReportingService._();

  static AppErrorRecorder? _recorder;

  /// Allows registering a remote sink (e.g. Crashlytics / Sentry) at startup.
  static void setRecorder(AppErrorRecorder? recorder) {
    _recorder = recorder;
  }

  /// Installs global error handlers on FlutterError and PlatformDispatcher.
  static void installGlobalHooks() {
    final previousFlutterError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      FlutterError.presentError(details);
      recordError(
        details.exception,
        details.stack,
        reason: details.context?.toDescription(),
        fatal: true,
      );
      if (previousFlutterError != null &&
          previousFlutterError != FlutterError.presentError) {
        previousFlutterError(details);
      }
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      recordError(error, stack, reason: 'PlatformDispatcher.onError', fatal: true);
      return true;
    };
  }

  static void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    bool fatal = false,
  }) {
    debugPrint(
      '[AppError${fatal ? ":FATAL" : ""}] ${reason ?? "Unhandled exception"}: $error',
    );
    final recorder = _recorder;
    if (recorder != null) {
      try {
        recorder(error, stackTrace, reason: reason, fatal: fatal);
      } catch (recorderErr) {
        debugPrint('[AppError] Custom error recorder failed: $recorderErr');
      }
    }
  }
}

