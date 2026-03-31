import 'dart:async';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';

class MonitoringService {
  MonitoringService._();

  static final MonitoringService instance = MonitoringService._();

  Future<void> initialize() async {
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  }

  Future<T> trace<T>(String name, Future<T> Function() action) async {
    final Trace trace = FirebasePerformance.instance.newTrace(name);
    await trace.start();
    try {
      return await action();
    } finally {
      await trace.stop();
    }
  }

  void recordNonFatal(Object error, StackTrace stack) {
    FirebaseCrashlytics.instance.recordError(error, stack, fatal: false);
  }

  Future<void> runGuarded(Future<void> Function() body) {
    final Completer<void> completer = Completer<void>();
    runZonedGuarded(
      () async {
        try {
          await body();
          if (!completer.isCompleted) {
            completer.complete();
          }
        } catch (error, stack) {
          FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
          if (!completer.isCompleted) {
            completer.completeError(error, stack);
          }
        }
      },
      (Object error, StackTrace stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        if (!completer.isCompleted) {
          completer.completeError(error, stack);
        }
      },
    );
    return completer.future;
  }
}
