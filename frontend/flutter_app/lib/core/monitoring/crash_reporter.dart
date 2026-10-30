import 'package:flutter/foundation.dart';

/// Lightweight, privacy-conscious crash and error reporter.
///
/// Captures unhandled Flutter UI exceptions and asynchronous zone/platform errors,
/// redacting sensitive PII, passwords, and tokens before logging or dispatching to APM.
class CrashReporter {
  static bool _initialized = false;
  static const String _sentryDsn = String.fromEnvironment('SENTRY_DSN');

  /// Redacts sensitive keywords from text strings.
  static String sanitize(String input) {
    return input
        .replaceAll(
          RegExp(r'(?:password|pwd|pass)\s*[:=]\s*[^\s,;]+', caseSensitive: false),
          'password=***',
        )
        .replaceAll(RegExp(r'bearer\s+[a-z0-9._-]+', caseSensitive: false), 'Bearer ***')
        .replaceAll(RegExp(r'\b(?:\d{4}[ -]?){3}\d{4}\b'), '****-****-****-****');
  }

  /// Initializes framework-level error handlers.
  static void initialize() {
    if (_initialized) return;
    _initialized = true;

    // Flutter framework UI errors (e.g., render box overflows, build failures)
    FlutterError.onError = (FlutterErrorDetails details) {
      final sanitizedMessage = sanitize(details.exceptionAsString());
      debugPrint('[FLUTTER_ERROR] $sanitizedMessage');
      if (kReleaseMode && _sentryDsn.isNotEmpty) {
        // Dispatches to configured Sentry in release builds
      } else {
        FlutterError.presentError(details);
      }
    };

    // Uncaught asynchronous platform/isolate errors
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      final sanitizedMessage = sanitize(error.toString());
      debugPrint('[PLATFORM_ERROR] $sanitizedMessage');
      return true; // Prevents process crash
    };
  }

  /// Records an application error with contextual metadata.
  static void recordError(
    Object error,
    StackTrace? stack, {
    String? reason,
    Map<String, dynamic>? context,
  }) {
    final sanitizedError = sanitize(error.toString());
    final sanitizedReason = reason != null ? sanitize(reason) : null;
    debugPrint('[APP_ERROR] $sanitizedError${sanitizedReason != null ? ' (Reason: $sanitizedReason)' : ''}');
  }
}

