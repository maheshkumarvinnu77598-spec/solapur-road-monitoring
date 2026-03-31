import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

class DashboardTimelinePoint {
  const DashboardTimelinePoint({
    required this.date,
    required this.count,
  });

  final DateTime date;
  final int count;

  factory DashboardTimelinePoint.fromMap(Map<String, dynamic> map) {
    return DashboardTimelinePoint(
      date: DateTime.tryParse(map['date'] as String? ?? '') ?? DateTime(1970),
      count: (map['count'] as num?)?.toInt() ?? 0,
    );
  }
}

class DashboardStats {
  const DashboardStats({
    required this.categories,
    required this.status,
    required this.timeline,
  });

  final Map<String, int> categories;
  final Map<String, int> status;
  final List<DashboardTimelinePoint> timeline;

  int get totalReports {
    final int statusSum = status.values.fold(0, (int sum, int value) => sum + value);
    if (statusSum > 0) {
      return statusSum;
    }
    return categories.values.fold(0, (int sum, int value) => sum + value);
  }

  int get pending => status['pending'] ?? 0;
  int get inProgress => status['in_progress'] ?? 0;
  int get completed => status['completed'] ?? 0;

  bool get isEmpty =>
      categories.values.every((int value) => value == 0) &&
      status.values.every((int value) => value == 0) &&
      timeline.every((DashboardTimelinePoint point) => point.count == 0);

  factory DashboardStats.empty() {
    return const DashboardStats(
      categories: <String, int>{
        'pothole': 0,
        'crack': 0,
        'garbage': 0,
        'water_logging': 0,
      },
      status: <String, int>{
        'pending': 0,
        'in_progress': 0,
        'completed': 0,
      },
      timeline: <DashboardTimelinePoint>[],
    );
  }

  factory DashboardStats.fromMap(Map<String, dynamic> map) {
    final Map<String, dynamic> rawCategories =
        map['categories'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final Map<String, dynamic> rawStatus =
        map['status'] as Map<String, dynamic>? ?? const <String, dynamic>{};
    final List<dynamic> rawTimeline = map['timeline'] as List<dynamic>? ?? const <dynamic>[];

    return DashboardStats(
      categories: <String, int>{
        'pothole': (rawCategories['pothole'] as num?)?.toInt() ?? 0,
        'crack': (rawCategories['crack'] as num?)?.toInt() ?? 0,
        'garbage': (rawCategories['garbage'] as num?)?.toInt() ?? 0,
        'water_logging': (rawCategories['water_logging'] as num?)?.toInt() ?? 0,
      },
      status: <String, int>{
        'pending': (rawStatus['pending'] as num?)?.toInt() ?? 0,
        'in_progress': (rawStatus['in_progress'] as num?)?.toInt() ?? 0,
        'completed': (rawStatus['completed'] as num?)?.toInt() ?? 0,
      },
      timeline: rawTimeline
          .whereType<Map<String, dynamic>>()
          .map(DashboardTimelinePoint.fromMap)
          .toList(growable: false),
    );
  }
}

class DashboardService {
  DashboardService({http.Client? client}) : _client = client ?? http.Client();

  static const String _defaultBaseUrl = 'http://192.168.0.215:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'ADMIN_API_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );

  final http.Client _client;

  Uri get _statsUri => Uri.parse('$_configuredBaseUrl/dashboard-stats');

  Future<DashboardStats> fetchStats() async {
    try {
      final http.Response response = await _client
          .get(_statsUri, headers: const <String, String>{'Accept': 'application/json'})
          .timeout(const Duration(seconds: 10));

      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw DashboardException(
          'Unable to load dashboard data. HTTP ${response.statusCode}.',
        );
      }

      final Map<String, dynamic> data = jsonDecode(response.body) as Map<String, dynamic>;
      return DashboardStats.fromMap(data);
    } on TimeoutException {
      throw const DashboardException('Dashboard request timed out. Please try again.');
    } on FormatException {
      throw const DashboardException('Dashboard response was not valid JSON.');
    } catch (error) {
      if (error is DashboardException) {
        rethrow;
      }
      throw DashboardException('Failed to fetch dashboard data: $error');
    }
  }

  void dispose() {
    _client.close();
  }
}

class DashboardException implements Exception {
  const DashboardException(this.message);

  final String message;

  @override
  String toString() => message;
}
