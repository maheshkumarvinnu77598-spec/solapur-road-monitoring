import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:geolocator/geolocator.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/duplicate_match.dart';
import '../models/report_model.dart';
import '../notifications/notification_service.dart';
import 'report_config.dart';

class ReportRepository {
  ReportRepository({
    FirebaseFirestore? firestore,
    NotificationService? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _notifications = notifications ?? NotificationService();

  final FirebaseFirestore _firestore;
  final NotificationService _notifications;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

  static const List<String> _statusPipeline = <String>[
    'Reported',
    'Assigned',
    'In Progress',
    'Under Review',
    'Fixed',
  ];

  Stream<List<ReportModel>> myReports(String reporterId) {
    return _reports
        .where('reporter_id', isEqualTo: reporterId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.map(ReportModel.fromDoc).toList(growable: false),
        );
  }

  Stream<List<ReportModel>> allReports() {
    return _reports
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.map(ReportModel.fromDoc).toList(growable: false),
        );
  }

  Future<ReportModel?> getReportById(String reportId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _reports
        .doc(reportId)
        .get();
    if (!snap.exists) {
      return null;
    }
    return ReportModel.fromDoc(snap);
  }

  Future<List<ReportModel>> fetchReportsInBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
    int pageSize = 120,
    int maxPages = 2,
  }) async {
    final Trace trace = FirebasePerformance.instance.newTrace(
      'map_fetch_reports_in_bounds',
    );
    await trace.start();
    try {
      final List<ReportModel> items = <ReportModel>[];
      DocumentSnapshot<Map<String, dynamic>>? cursor;

      for (int page = 0; page < maxPages; page++) {
        Query<Map<String, dynamic>> q = _reports
            .where('latitude', isGreaterThanOrEqualTo: minLatitude)
            .where('latitude', isLessThanOrEqualTo: maxLatitude)
            .orderBy('latitude')
            .limit(pageSize);

        if (cursor != null) {
          q = q.startAfterDocument(cursor);
        }

        final QuerySnapshot<Map<String, dynamic>> snap = await q.get();
        if (snap.docs.isEmpty) {
          break;
        }

        cursor = snap.docs.last;

        final List<ReportModel> filtered = snap.docs
            .map(ReportModel.fromDoc)
            .where(
              (ReportModel r) =>
                  r.hasValidCoordinates &&
                  r.longitude >= minLongitude &&
                  r.longitude <= maxLongitude,
            )
            .toList(growable: false);
        items.addAll(filtered);

        if (snap.docs.length < pageSize) {
          break;
        }
      }

      return items;
    } finally {
      await trace.stop();
    }
  }

  Future<String> uploadReportImage(File imageFile, String reporterId) async {
    try {
      final String fileName =
          'reports/${DateTime.now().millisecondsSinceEpoch}_$reporterId.jpg';
      return await _uploadImageToSupabase(imageFile, fileName);
    } catch (_) {
      throw Exception('Image upload failed');
    }
  }

  Future<bool> canSubmitReport({
    required String reporterId,
    int maxReports = 5,
    Duration window = const Duration(hours: 1),
  }) async {
    final DateTime threshold = DateTime.now().subtract(window);
    final QuerySnapshot<Map<String, dynamic>> recent = await _reports
        .where('reporter_id', isEqualTo: reporterId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(threshold),
        )
        .get();
    return recent.size < maxReports;
  }

  Future<ReportModel?> findNearbyDuplicate({
    required String category,
    required double latitude,
    required double longitude,
    double radiusMeters = 40,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> nearbyReports = await _reports
        .where('category', isEqualTo: category)
        .get();

    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in nearbyReports.docs) {
      final Map<String, dynamic> data = doc.data();
      final double existingLat = (data['latitude'] as num?)?.toDouble() ?? 0;
      final double existingLng = (data['longitude'] as num?)?.toDouble() ?? 0;
      final double distance = Geolocator.distanceBetween(
        latitude,
        longitude,
        existingLat,
        existingLng,
      );
      if (distance <= radiusMeters) {
        return ReportModel.fromDoc(doc);
      }
    }
    return null;
  }

  Future<DuplicateMatch?> findHighConfidenceDuplicate({
    required String category,
    required double latitude,
    required double longitude,
  }) async {
    final QuerySnapshot<Map<String, dynamic>> nearbyReports = await _reports
        .where('category', isEqualTo: category)
        .get();

    DuplicateMatch? best;
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in nearbyReports.docs) {
      final ReportModel report = ReportModel.fromDoc(doc);
      final double score = _duplicateScore(
        report: report,
        category: category,
        latitude: latitude,
        longitude: longitude,
      );
      if (score >= 0.75 && (best == null || score > best.confidence)) {
        best = DuplicateMatch(report: report, confidence: score);
      }
    }
    return best;
  }

  double _duplicateScore({
    required ReportModel report,
    required String category,
    required double latitude,
    required double longitude,
  }) {
    final double distance = Geolocator.distanceBetween(
      latitude,
      longitude,
      report.latitude,
      report.longitude,
    );
    final double distanceScore = (1 - (distance / 120)).clamp(0, 1);

    final double ageHours =
        DateTime.now().difference(report.timestamp).inMinutes / 60.0;
    final double timeScore = (1 - (ageHours / 24)).clamp(0, 1);

    final double categoryScore =
        report.category.toLowerCase() == category.toLowerCase() ? 1 : 0;
    final double crowdScore = min(report.reportCount / 10, 1.0);

    return (distanceScore * 0.45) +
        (timeScore * 0.25) +
        (categoryScore * 0.2) +
        (crowdScore * 0.1);
  }

  Future<void> supportExistingReport(
    String reportId, {
    String? citizenId,
  }) async {
    try {
      final DocumentReference<Map<String, dynamic>> ref = _reports.doc(
        reportId,
      );
      final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
      final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
      final int currentCount =
          (data['duplicate_count'] as num?)?.toInt() ??
          (data['report_count'] as num?)?.toInt() ??
          1;
      final int nextCount = currentCount + 1;
      final String category = data['category'] as String? ?? 'Unknown';
      final bool slaBreached = data['sla_breach_flag'] as bool? ?? false;
      final String nextPriority = smartPriority(
        category: category,
        duplicateCount: nextCount,
        slaBreached: slaBreached,
      );

      await ref.update(<String, dynamic>{
        'report_count': FieldValue.increment(1),
        'duplicate_count': FieldValue.increment(1),
        'duplicate_attached': true,
        'priority': nextPriority,
        if (citizenId != null && citizenId.isNotEmpty)
          'supporter_ids': FieldValue.arrayUnion(<String>[citizenId]),
        'timestamp': FieldValue.serverTimestamp(),
      });
      if (citizenId != null && citizenId.isNotEmpty) {
        await _updateCitizenReputation(userId: citizenId, citizenScoreDelta: 2);
      }
      await _applyPriorityEscalation(reportId);
    } on FirebaseException {
      rethrow;
    }
  }

  Future<bool> hasRecentImageHash(String imageHash) async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _reports
        .where('image_hash', isEqualTo: imageHash)
        .limit(1)
        .get();
    return snap.docs.isNotEmpty;
  }

  Future<String> createReport({
    required String category,
    required String description,
    required String imageUrl,
    required double latitude,
    required double longitude,
    required String reporterId,
    String? imageHash,
    DateTime? imageCapturedAt,
    String? aiSeverity,
    double? aiConfidence,
    List<Map<String, dynamic>> aiBoxes = const <Map<String, dynamic>>[],
  }) async {
    final Trace trace = FirebasePerformance.instance.newTrace(
      'report_create_submit',
    );
    await trace.start();

    try {
      final String priority = priorityForCategory(category);

      final DocumentReference<Map<String, dynamic>> docRef = _reports.doc();
      await docRef.set(<String, dynamic>{
        'id': docRef.id,
        'report_id': docRef.id,
        'category': category,
        'description': description,
        'image_url': imageUrl,
        'location': GeoPoint(latitude, longitude),
        'latitude': latitude,
        'longitude': longitude,
        'priority': priority,
        'status': 'Reported',
        'reporter_id': reporterId,
        'assigned_worker_id': null,
        'assigned_worker_name': null,
        'repair_image': null,
        'repair_image_url': null,
        'report_count': 1,
        'duplicate_count': 1,
        'supporter_ids': <String>[reporterId],
        'assigned_at': null,
        'started_at': null,
        'under_review_at': null,
        'resolved_at': null,
        'sla_breach_flag': false,
        'verify_fixed_count': 0,
        'verify_not_fixed_count': 0,
        'completion_timestamp': null,
        'image_hash': imageHash,
        'image_captured_at': imageCapturedAt == null
            ? null
            : Timestamp.fromDate(imageCapturedAt),
        'ai_severity': aiSeverity,
        'ai_confidence': aiConfidence,
        'ai_boxes': aiBoxes,
        'created_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _notifications.notifyUser(
        userId: reporterId,
        title: 'Report Accepted',
        body: 'Your issue has been recorded and is awaiting assignment.',
        type: 'Report Accepted',
        reportId: docRef.id,
      );

      if (priority == 'high' || priority == 'critical') {
        await _notifications.notifyUser(
          userId: reporterId,
          title: 'High Priority Issue Reported',
          body: 'Your issue has been recorded with priority: $priority.',
          type: 'Report Status Updated',
          reportId: docRef.id,
        );
      }

      await _updateCitizenReputation(userId: reporterId, citizenScoreDelta: 3);

      return docRef.id;
    } on FirebaseException {
      rethrow;
    } finally {
      await trace.stop();
    }
  }

  Future<void> submitOrMergeReport({
    required String category,
    required String description,
    required String imageUrl,
    required double latitude,
    required double longitude,
    required String reporterId,
  }) async {
    final ReportModel? duplicate = await findNearbyDuplicate(
      category: category,
      latitude: latitude,
      longitude: longitude,
      radiusMeters: 40,
    );

    if (duplicate != null) {
      await supportExistingReport(duplicate.id, citizenId: reporterId);
      return;
    }

    await createReport(
      category: category,
      description: description,
      imageUrl: imageUrl,
      latitude: latitude,
      longitude: longitude,
      reporterId: reporterId,
    );
  }

  Future<void> assignWorker({
    required String reportId,
    required String workerId,
    required String workerName,
    String actorId = 'system',
    String actorRole = 'system',
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
          .doc(reportId)
          .get();
      final Map<String, dynamic> reportData =
          reportDoc.data() ?? <String, dynamic>{};
      final String previousStatus =
          reportData['status'] as String? ?? 'Reported';

      await _reports.doc(reportId).update(<String, dynamic>{
        'assigned_worker_id': workerId,
        'assigned_worker_name': workerName,
        'status': 'Assigned',
        'assigned_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _firestore
          .collection('workers')
          .doc(workerId)
          .set(<String, dynamic>{
            'pending_tasks': FieldValue.increment(1),
            'assigned_tasks': FieldValue.increment(1),
          }, SetOptions(merge: true));
      await _recomputeCredibility(workerId);

      await _logReportEvent(
        reportId: reportId,
        actorId: actorId,
        actorRole: actorRole,
        previousStatus: previousStatus,
        newStatus: 'Assigned',
      );

      final String reporterId = reportData['reporter_id'] as String? ?? '';
      if (reporterId.isNotEmpty) {
        await _notifications.notifyUser(
          userId: reporterId,
          title: 'Issue Assigned',
          body: 'Your reported issue has been assigned to a worker.',
          type: 'Report Status Updated',
          reportId: reportId,
        );
      }

      await _notifications.notifyUser(
        userId: workerId,
        title: 'Worker Assigned',
        body: 'A new issue has been assigned to you.',
        type: 'Worker Assigned',
        reportId: reportId,
      );
    } on FirebaseException {
      rethrow;
    }
  }

  Future<void> updateStatus(
    String reportId,
    String status, {
    String actorId = 'system',
    String actorRole = 'system',
  }) async {
    try {
      if (!_statusPipeline.contains(status)) {
        throw StateError('Unsupported status transition target: $status');
      }

      final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
          .doc(reportId)
          .get();
      final Map<String, dynamic> data = reportDoc.data() ?? <String, dynamic>{};
      final String previousStatus = data['status'] as String? ?? 'Reported';

      if (!_isValidTransition(
        previousStatus: previousStatus,
        nextStatus: status,
      )) {
        throw StateError(
          'Invalid status transition: $previousStatus -> $status',
        );
      }
      if (previousStatus == status) {
        return;
      }

      final Map<String, dynamic> updates = <String, dynamic>{
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      };

      if (status == 'In Progress' && data['started_at'] == null) {
        updates['started_at'] = FieldValue.serverTimestamp();
      }
      if (status == 'Under Review' && data['under_review_at'] == null) {
        updates['under_review_at'] = FieldValue.serverTimestamp();
      }
      if (status == 'Fixed') {
        updates['resolved_at'] = FieldValue.serverTimestamp();
        updates['completion_timestamp'] = FieldValue.serverTimestamp();
        updates['completed_by'] = actorId;
        updates['completed_at'] = FieldValue.serverTimestamp();
        updates['sla_breach_flag'] = _isSlaBreached(data);
        updates['verify_fixed_count'] = 0;
        updates['verify_not_fixed_count'] = 0;
      }

      await _reports.doc(reportId).update(updates);

      await _logReportEvent(
        reportId: reportId,
        actorId: actorId,
        actorRole: actorRole,
        previousStatus: previousStatus,
        newStatus: status,
      );

      final String reporterId = data['reporter_id'] as String? ?? '';
      if (reporterId.isNotEmpty) {
        if (status == 'Fixed') {
          await _notifications.notifyUser(
            userId: reporterId,
            title: 'Repair Verified',
            body: 'Your reported issue is fixed and verified.',
            type: 'Repair Verified',
            reportId: reportId,
          );
        } else {
          await _notifications.notifyUser(
            userId: reporterId,
            title: 'Report Status Updated',
            body: 'Your issue status is now "$status".',
            type: 'Report Status Updated',
            reportId: reportId,
          );
        }
      }

      final String workerDocId = data['assigned_worker_id'] as String? ?? '';
      if (status == 'Fixed' && workerDocId.isNotEmpty) {
        await _applyWorkerCredibility(workerDocId, data);
        await _notifications.notifyUser(
          userId: workerDocId,
          title: 'Repair Verified',
          body: 'Your repair work has been verified.',
          type: 'Repair Verified',
          reportId: reportId,
        );
      } else if (status == 'Assigned' && workerDocId.isNotEmpty) {
        await _notifications.notifyUser(
          userId: workerDocId,
          title: 'Worker Assigned',
          body: 'A task has been assigned to you.',
          type: 'Worker Assigned',
          reportId: reportId,
        );
      }
    } on FirebaseException {
      rethrow;
    }
  }

  /// Complete a repair directly from a worker action.
  ///
  /// This sets the report to Fixed, tags the worker as the completer, and
  /// updates the completion timestamp.
  Future<void> completeRepair({
    required String reportId,
    required String workerId,
  }) async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
          .doc(reportId)
          .get();
      final Map<String, dynamic> data = reportDoc.data() ?? <String, dynamic>{};
      final String previousStatus = data['status'] as String? ?? 'Reported';

      final Map<String, dynamic> updates = <String, dynamic>{
        'status': 'Fixed',
        'completed_by': workerId,
        'completed_at': FieldValue.serverTimestamp(),
        'resolved_at': FieldValue.serverTimestamp(),
        'completion_timestamp': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
        'sla_breach_flag': _isSlaBreached(data),
        'verify_fixed_count': 0,
        'verify_not_fixed_count': 0,
      };

      await _reports.doc(reportId).update(updates);

      await _logReportEvent(
        reportId: reportId,
        actorId: workerId,
        actorRole: 'worker',
        previousStatus: previousStatus,
        newStatus: 'Fixed',
      );

      final String reporterId = data['reporter_id'] as String? ?? '';
      if (reporterId.isNotEmpty) {
        await _notifications.notifyUser(
          userId: reporterId,
          title: 'Repair Verified',
          body: 'Your reported issue is fixed and verified.',
          type: 'Repair Verified',
          reportId: reportId,
        );
      }

      final String workerDocId = data['assigned_worker_id'] as String? ?? '';
      if (workerDocId.isNotEmpty) {
        await _applyWorkerCredibility(workerDocId, data);
        await _notifications.notifyUser(
          userId: workerDocId,
          title: 'Repair Verified',
          body: 'Your repair work has been verified.',
          type: 'Repair Verified',
          reportId: reportId,
        );
      }
    } on FirebaseException {
      rethrow;
    }
  }

  Future<void> uploadRepairImage({
    required String reportId,
    required File imageFile,
    required String workerId,
  }) async {
    try {
      final String fileName =
          'repairs/$workerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String url = await _uploadImageToSupabase(imageFile, fileName);

      final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
          .doc(reportId)
          .get();
      final Map<String, dynamic> data = reportDoc.data() ?? <String, dynamic>{};
      final String previousStatus = data['status'] as String? ?? 'Reported';

      await _reports.doc(reportId).update(<String, dynamic>{
        'repair_image': url,
        'repair_image_url': url,
        'status': 'Under Review',
        'under_review_at': FieldValue.serverTimestamp(),
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });

      await _logReportEvent(
        reportId: reportId,
        actorId: workerId,
        actorRole: 'worker',
        previousStatus: previousStatus,
        newStatus: 'Under Review',
      );

      final String reporterId = data['reporter_id'] as String? ?? '';
      if (reporterId.isNotEmpty) {
        await _notifications.notifyUser(
          userId: reporterId,
          title: 'Repair Verification Request',
          body: 'A worker uploaded repair proof. Please verify the repair.',
          type: 'Repair Verification Request',
          reportId: reportId,
        );
      }
    } on FirebaseException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<void> markWorkerAttendance({
    required String reportId,
    required String workerId,
    required File selfieImage,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final String fileName =
          'attendance/$workerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String selfieUrl = await _uploadImageToSupabase(
        selfieImage,
        fileName,
      );
      final DocumentReference<Map<String, dynamic>> topLevelAttendanceRef =
          _firestore.collection('attendance').doc();
      final DocumentReference<Map<String, dynamic>> reportAttendanceRef =
          _reports
              .doc(reportId)
              .collection('attendance')
              .doc(topLevelAttendanceRef.id);
      final WriteBatch batch = _firestore.batch();

      final Map<String, dynamic> attendanceData = <String, dynamic>{
        'worker_id': workerId,
        'task_id': reportId,
        'report_id': reportId,
        'check_in_time': FieldValue.serverTimestamp(),
        'latitude': latitude,
        'longitude': longitude,
        'selfie_image': selfieUrl,
      };
      batch.set(topLevelAttendanceRef, attendanceData);
      batch.set(reportAttendanceRef, attendanceData);
      await batch.commit();
    } on FirebaseException {
      rethrow;
    } catch (_) {
      rethrow;
    }
  }

  Future<String> _uploadImageToSupabase(
    File imageFile,
    String fileName, {
    String bucket = 'report-images',
  }) async {
    if (!imageFile.existsSync()) {
      throw const FileSystemException('Image file not found');
    }

    final SupabaseClient supabase = Supabase.instance.client;
    await supabase.storage
        .from(bucket)
        .upload(
          fileName,
          imageFile,
          fileOptions: const FileOptions(
            cacheControl: '3600',
            upsert: false,
            contentType: 'image/jpeg',
          ),
        );

    return supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  Future<void> verifyRepair({
    required String reportId,
    required String userId,
    required bool isFixed,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _reports.doc(reportId);

    if (isFixed) {
      await ref.update(<String, dynamic>{
        'verify_fixed_count': FieldValue.increment(1),
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _updateCitizenReputation(
        userId: userId,
        approvedDelta: 1,
        citizenScoreDelta: 5,
      );
      return;
    }

    final Map<String, dynamic> updates = <String, dynamic>{
      'verify_not_fixed_count': FieldValue.increment(1),
      'updated_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    };

    await ref.update(updates);
    await _updateCitizenReputation(
      userId: userId,
      rejectedDelta: 1,
      citizenScoreDelta: 1,
    );

    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final int notFixed = (data['verify_not_fixed_count'] as num?)?.toInt() ?? 0;
    if (notFixed >= 2) {
      final String previousStatus = data['status'] as String? ?? 'Under Review';
      await ref.update(<String, dynamic>{
        'status': 'Assigned',
        'repair_image': null,
        'repair_image_url': null,
        'under_review_at': null,
        'resolved_at': null,
        'completion_timestamp': null,
        'updated_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _logReportEvent(
        reportId: reportId,
        actorId: userId,
        actorRole: 'citizen',
        previousStatus: previousStatus,
        newStatus: 'Assigned',
      );
      final String workerId = data['assigned_worker_id'] as String? ?? '';
      if (workerId.isNotEmpty) {
        await _notifications.notifyUser(
          userId: workerId,
          title: 'Issue Reopened',
          body: 'A citizen rejected the repair verification. Please revisit.',
          type: 'Issue Reopened',
          reportId: reportId,
        );
      }
    }
  }

  bool _isValidTransition({
    required String previousStatus,
    required String nextStatus,
  }) {
    if (!_statusPipeline.contains(previousStatus)) {
      return nextStatus == 'Reported';
    }
    final int currentIndex = _statusPipeline.indexOf(previousStatus);
    final int nextIndex = _statusPipeline.indexOf(nextStatus);
    return nextIndex == currentIndex + 1;
  }

  Future<void> _updateCitizenReputation({
    required String userId,
    int approvedDelta = 0,
    int rejectedDelta = 0,
    int citizenScoreDelta = 0,
  }) async {
    final DocumentReference<Map<String, dynamic>> userRef = _firestore
        .collection('users')
        .doc(userId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await userRef.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};

    final int approved =
        ((data['reports_approved'] as num?)?.toInt() ?? 0) + approvedDelta;
    final int rejected =
        ((data['reports_rejected'] as num?)?.toInt() ?? 0) + rejectedDelta;
    final int total = approved + rejected;
    final double accuracy = total == 0 ? 100 : (approved / total) * 100;
    final int citizenScore =
        ((data['citizen_score'] as num?)?.toInt() ?? 0) + citizenScoreDelta;

    await userRef.set(<String, dynamic>{
      'reports_approved': approved,
      'reports_rejected': rejected,
      'accuracy_score': double.parse(accuracy.toStringAsFixed(1)),
      'citizen_score': citizenScore,
    }, SetOptions(merge: true));
  }

  Future<void> _applyPriorityEscalation(String reportId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _reports
        .doc(reportId)
        .get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final int supportCount = (data['report_count'] as num?)?.toInt() ?? 1;

    final String escalatedPriority = smartPriority(
      category: data['category'] as String? ?? 'Unknown',
      duplicateCount: supportCount,
      slaBreached: data['sla_breach_flag'] as bool? ?? false,
    );

    final String currentPriority = (data['priority'] as String? ?? 'low')
        .toLowerCase();
    if ((priorityRank[escalatedPriority] ?? 0) <=
        (priorityRank[currentPriority] ?? 0)) {
      return;
    }

    await _reports.doc(reportId).update(<String, dynamic>{
      'priority': escalatedPriority,
      'priority_escalated': true,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  bool _isSlaBreached(Map<String, dynamic> report) {
    final Timestamp? assignedTs = report['assigned_at'] as Timestamp?;
    if (assignedTs == null) {
      return false;
    }

    final DateTime assignedAt = assignedTs.toDate();
    final DateTime now = DateTime.now();
    final String priority = (report['priority'] as String? ?? 'low')
        .toLowerCase();
    final String category = report['category'] as String? ?? 'Unknown';
    final Duration sla = slaForReport(category: category, priority: priority);

    return now.isAfter(assignedAt.add(sla));
  }

  Future<void> _applyWorkerCredibility(
    String workerDocId,
    Map<String, dynamic> report,
  ) async {
    final DocumentReference<Map<String, dynamic>> workerRef = _firestore
        .collection('workers')
        .doc(workerDocId);

    int scoreDelta = 5;
    final Timestamp? assignedTs = report['assigned_at'] as Timestamp?;
    if (assignedTs != null) {
      final DateTime assigned = assignedTs.toDate();
      final String priority = (report['priority'] as String? ?? 'low')
          .toLowerCase();
      final String category = report['category'] as String? ?? 'Unknown';
      final Duration sla = slaForReport(category: category, priority: priority);
      if (DateTime.now().isAfter(assigned.add(sla))) {
        scoreDelta = -2;
      }
    }

    await workerRef.set(<String, dynamic>{
      'credibility_score': FieldValue.increment(scoreDelta),
      'completed_tasks': FieldValue.increment(1),
      'pending_tasks': FieldValue.increment(-1),
    }, SetOptions(merge: true));
    await _recomputeCredibility(workerDocId);
  }

  Stream<List<Map<String, dynamic>>> citizenLeaderboard({int limit = 10}) {
    return _firestore
        .collection('users')
        .orderBy('citizen_score', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(growable: false),
        );
  }

  Stream<List<Map<String, dynamic>>> workerLeaderboard({int limit = 10}) {
    return _firestore
        .collection('workers')
        .orderBy('credibility_score', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) =>
              snapshot.docs.map((doc) => doc.data()).toList(growable: false),
        );
  }

  Stream<Map<String, dynamic>> cityAnalytics() {
    return _reports.snapshots().asyncMap((
      QuerySnapshot<Map<String, dynamic>> snapshot,
    ) async {
      final List<ReportModel> reports = snapshot.docs
          .map(ReportModel.fromDoc)
          .toList(growable: false);
      final int total = reports.length;
      final int resolved = reports.where((r) => r.status == 'Fixed').length;
      final Iterable<ReportModel> withCompletion = reports.where(
        (r) => r.completionTimestamp != null,
      );
      final double averageRepairHours = withCompletion.isEmpty
          ? 0
          : withCompletion
                    .map(
                      (r) => r.completionTimestamp!
                          .difference(r.timestamp)
                          .inMinutes
                          .toDouble(),
                    )
                    .reduce((a, b) => a + b) /
                withCompletion.length /
                60;

      final Map<String, int> categories = <String, int>{};
      final Map<String, int> wards = <String, int>{};
      for (final report in reports) {
        categories.update(
          report.category,
          (value) => value + 1,
          ifAbsent: () => 1,
        );
        final String ward = _wardForCoordinates(
          latitude: report.latitude,
          longitude: report.longitude,
        );
        wards.update(ward, (value) => value + 1, ifAbsent: () => 1);
      }

      return <String, dynamic>{
        'total_reports': total,
        'resolved_reports': resolved,
        'average_repair_hours': double.parse(
          averageRepairHours.toStringAsFixed(1),
        ),
        'top_categories': categories.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
        'ward_performance': wards.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)),
      };
    });
  }

  String _wardForCoordinates({
    required double latitude,
    required double longitude,
  }) {
    if (latitude >= 17.70) {
      return longitude >= 75.90 ? 'North East Ward' : 'North West Ward';
    }
    return longitude >= 75.90 ? 'South East Ward' : 'South West Ward';
  }

  Future<void> _recomputeCredibility(String workerDocId) async {
    final DocumentReference<Map<String, dynamic>> workerRef = _firestore
        .collection('workers')
        .doc(workerDocId);
    await _firestore.runTransaction((tx) async {
      final snap = await tx.get(workerRef);
      final data = snap.data() ?? <String, dynamic>{};
      final int assigned = (data['assigned_tasks'] as num?)?.toInt() ?? 0;
      final int completed = (data['completed_tasks'] as num?)?.toInt() ?? 0;
      final double score = assigned == 0 ? 0 : completed / assigned;
      tx.set(workerRef, <String, dynamic>{
        'credibility_score': double.parse(score.toStringAsFixed(2)),
      }, SetOptions(merge: true));
    });
  }

  Future<void> _logReportEvent({
    required String reportId,
    required String actorId,
    required String actorRole,
    required String previousStatus,
    required String newStatus,
  }) async {
    await _reports
        .doc(reportId)
        .collection('report_events')
        .add(<String, dynamic>{
          'actor_id': actorId,
          'actor_role': actorRole,
          'previous_status': previousStatus,
          'new_status': newStatus,
          'timestamp': FieldValue.serverTimestamp(),
        });
  }

  Future<bool> isAttendanceMarkedToday(String workerId) async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('worker_attendance')
        .where('worker_id', isEqualTo: workerId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .get();

    return snap.docs.isNotEmpty;
  }

  Future<void> markDailyAttendance({
    required String workerId,
    required File faceImage,
    double? latitude,
    double? longitude,
  }) async {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    final String fileName = '$workerId/$timestamp.jpg';
    final String imageUrl = await _uploadAttendanceImageWithRetry(
      faceImage,
      fileName,
    );

    await _firestore.collection('worker_attendance').add(<String, dynamic>{
      'worker_id': workerId,
      'image_url': imageUrl,
      'timestamp': FieldValue.serverTimestamp(),
      'latitude': latitude,
      'longitude': longitude,
      'status': 'present',
    });
  }

  Future<String> _uploadAttendanceImageWithRetry(
    File imageFile,
    String fileName,
  ) async {
    Object? lastError;
    for (int attempt = 0; attempt < 2; attempt++) {
      try {
        return await _uploadImageToSupabase(
          imageFile,
          fileName,
          bucket: 'worker-attendance',
        );
      } catch (error) {
        lastError = error;
      }
    }
    throw lastError ?? Exception('Attendance upload failed');
  }
}
