import 'package:cloud_firestore/cloud_firestore.dart';

import 'ai_result.dart';

class ReportModel {
  const ReportModel({
    required this.id,
    required this.category,
    required this.description,
    required this.imageUrl,
    required this.latitude,
    required this.longitude,
    required this.priority,
    required this.status,
    required this.reporterId,
    required this.reportCount,
    required this.timestamp,
    this.assignedAt,
    this.startedAt,
    this.underReviewAt,
    this.completionTimestamp,
    this.slaBreachFlag = false,
    this.verifyFixedCount = 0,
    this.verifyNotFixedCount = 0,
    this.aiConfidence,
    this.aiSeverity,
    this.aiBoxes = const <AiBox>[],
    this.assignedWorker,
    this.repairImage,
  });

  final String id;
  final String category;
  final String description;
  final String imageUrl;
  final double latitude;
  final double longitude;
  final String priority;
  final String status;
  final String reporterId;
  final String? assignedWorker;
  final String? repairImage;
  final int reportCount;
  final DateTime timestamp;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? underReviewAt;
  final DateTime? completionTimestamp;
  final bool slaBreachFlag;
  final int verifyFixedCount;
  final int verifyNotFixedCount;
  final double? aiConfidence;
  final String? aiSeverity;
  final List<AiBox> aiBoxes;

  factory ReportModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return ReportModel(
      id: data['report_id'] as String? ?? doc.id,
      category: data['category'] as String? ?? 'Unknown',
      description: data['description'] as String? ?? '',
      imageUrl: data['image_url'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      priority: data['priority'] as String? ?? 'low',
      status: data['status'] as String? ?? 'Reported',
      reporterId: data['reporter_id'] as String? ?? '',
      assignedWorker: data['assigned_worker'] as String?,
      repairImage:
          data['repair_image_url'] as String? ??
          data['repair_image'] as String?,
      reportCount: (data['report_count'] as num?)?.toInt() ?? 1,
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      assignedAt: (data['assigned_at'] as Timestamp?)?.toDate(),
      startedAt: (data['started_at'] as Timestamp?)?.toDate(),
      underReviewAt: (data['under_review_at'] as Timestamp?)?.toDate(),
      completionTimestamp:
          (data['completion_timestamp'] as Timestamp?)?.toDate() ??
          (data['resolved_at'] as Timestamp?)?.toDate(),
      slaBreachFlag: data['sla_breach_flag'] as bool? ?? false,
      verifyFixedCount: (data['verify_fixed_count'] as num?)?.toInt() ?? 0,
      verifyNotFixedCount:
          (data['verify_not_fixed_count'] as num?)?.toInt() ?? 0,
      aiConfidence: (data['ai_confidence'] as num?)?.toDouble(),
      aiSeverity: data['ai_severity'] as String?,
      aiBoxes: ((data['ai_boxes'] as List<dynamic>?) ?? const <dynamic>[])
          .whereType<Map<String, dynamic>>()
          .map(AiBox.fromMap)
          .toList(growable: false),
    );
  }
}
