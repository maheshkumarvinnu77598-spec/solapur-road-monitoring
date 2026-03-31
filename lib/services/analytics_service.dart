import 'package:firebase_analytics/firebase_analytics.dart';

class AnalyticsService {
  AnalyticsService._();

  static final AnalyticsService instance = AnalyticsService._();

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  Future<void> logReportSubmitted({
    required String category,
    required String priority,
    required bool queuedOffline,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'report_submitted',
        parameters: <String, Object>{
          'category': category,
          'priority': priority,
          'queued_offline': queuedOffline,
        },
      );
    } catch (_) {}
  }

  Future<void> logWorkerTaskStarted({required String taskId}) async {
    try {
      await _analytics.logEvent(
        name: 'worker_task_started',
        parameters: <String, Object>{'task_id': taskId},
      );
    } catch (_) {}
  }

  Future<void> logWorkerAttendanceMarked({required String taskId}) async {
    try {
      await _analytics.logEvent(
        name: 'worker_attendance_marked',
        parameters: <String, Object>{'task_id': taskId},
      );
    } catch (_) {}
  }

  Future<void> logRepairVerified({
    required String reportId,
    required bool isFixed,
  }) async {
    try {
      await _analytics.logEvent(
        name: 'repair_verified',
        parameters: <String, Object>{
          'report_id': reportId,
          'is_fixed': isFixed,
        },
      );
    } catch (_) {}
  }
}
