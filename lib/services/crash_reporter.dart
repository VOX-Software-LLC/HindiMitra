import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Single place where uncaught errors end up.
///
/// It logs to the console today. To get crash reports from real devices, add
/// `firebase_crashlytics` or `sentry_flutter` and forward to it from [record]
/// (that needs a Firebase project / Sentry DSN, so it is not wired up here).
class CrashReporter {
  static final List<String> recent = [];

  static void record(Object error, StackTrace? stack, {String? reason, bool fatal = false}) {
    final line = '[${fatal ? 'FATAL' : 'error'}] ${reason ?? ''} $error';
    recent.add(line);
    if (recent.length > 50) recent.removeAt(0);
    debugPrint(line);
    if (stack != null) debugPrint(stack.toString());
    // TODO: FirebaseCrashlytics.instance.recordError(error, stack, reason: reason, fatal: fatal);
  }

  /// Hooks Flutter + platform error handlers, and replaces the release-mode
  /// grey box with a friendly "try again" panel so a broken widget never
  /// freezes the whole screen silently.
  static void install() {
    final prev = FlutterError.onError;
    FlutterError.onError = (details) {
      record(details.exception, details.stack, reason: details.context?.toString(), fatal: false);
      prev?.call(details);
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      record(error, stack, reason: 'uncaught', fatal: true);
      return true;
    };
    if (kReleaseMode) {
      ErrorWidget.builder = (details) => const Material(
            color: Color(0xFFFCF9EE),
            child: Center(child: Padding(
              padding: EdgeInsets.all(24),
              child: Text('Oops! Something went wrong here.\nPlease go back and try again.',
                  textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFF5B4A2E))),
            )),
          );
    }
  }
}
