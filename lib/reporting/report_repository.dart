import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:geolocator/geolocator.dart';

import '../models/duplicate_match.dart';
import '../models/report_model.dart';
import '../notifications/notification_service.dart';
import 'report_config.dart';

class ReportRepository {
  ReportRepository({
    FirebaseFirestore? firestore,
    FirebaseStorage? storage,
    NotificationService? notifications,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _storage = storage ?? FirebaseStorage.instance,
       _notifications = notifications ?? NotificationService();

  final FirebaseFirestore _firestore;
  final FirebaseStorage _storage;
  final NotificationService _notifications;

  CollectionReference<Map<String, dynamic>> get _reports =>
      _firestore.collection('reports');

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
                  r.longitude >= minLongitude && r.longitude <= maxLongitude,
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
    final String fileName =
        'reports/$reporterId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final TaskSnapshot snap = await _storage.ref(fileName).putFile(imageFile);
    return snap.ref.getDownloadURL();
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
    double radiusMeters = 50,
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

  Future<void> supportExistingReport(String reportId) async {
    final DocumentReference<Map<String, dynamic>> ref = _reports.doc(reportId);
    await ref.update(<String, dynamic>{
      'report_count': FieldValue.increment(1),
      'timestamp': FieldValue.serverTimestamp(),
    });
    await _applyPriorityEscalation(reportId);
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
        'report_id': docRef.id,
        'category': category,
        'description': description,
        'image_url': imageUrl,
        'latitude': latitude,
        'longitude': longitude,
        'priority': priority,
        'status': 'Reported',
        'reporter_id': reporterId,
        'assigned_worker': null,
        'repair_image': null,
        'report_count': 1,
        'assigned_at': null,
        'started_at': null,
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
        'timestamp': FieldValue.serverTimestamp(),
      });

      if (priority == 'high' || priority == 'critical') {
        await _notifications.notifyUser(
          userId: reporterId,
          title: 'High Priority Issue Reported',
          body: 'Your issue has been recorded with priority: $priority.',
          reportId: docRef.id,
        );
      }

      return docRef.id;
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
      radiusMeters: 50,
    );

    if (duplicate != null) {
      await supportExistingReport(duplicate.id);
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
    String actorId = 'system',
    String actorRole = 'system',
  }) async {
    final DateTime now = DateTime.now();
    final DateTime start = DateTime(now.year, now.month, now.day, 9);
    final DateTime end = DateTime(now.year, now.month, now.day, 18);

    final bool inWindow = !now.isBefore(start) && now.isBefore(end);
    DateTime? scheduleAt;

    if (!inWindow) {
      final DateTime nextDay = now.hour >= 18
          ? now.add(const Duration(days: 1))
          : now;
      scheduleAt = DateTime(nextDay.year, nextDay.month, nextDay.day, 9);
    }

    final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
        .doc(reportId)
        .get();
    final Map<String, dynamic> reportData =
        reportDoc.data() ?? <String, dynamic>{};
    final String previousStatus = reportData['status'] as String? ?? 'Reported';

    await _reports.doc(reportId).update(<String, dynamic>{
      'assigned_worker': workerId,
      'status': inWindow ? 'Assigned' : 'Reported',
      'assigned_at': FieldValue.serverTimestamp(),
      'assignment_scheduled_for': scheduleAt == null
          ? null
          : Timestamp.fromDate(scheduleAt),
    });

    await _firestore.collection('workers').doc(workerId).set(<String, dynamic>{
      'pending_tasks': FieldValue.increment(1),
      'assigned_tasks': FieldValue.increment(1),
    }, SetOptions(merge: true));
    await _recomputeCredibility(workerId);

    if (inWindow) {
      await _logReportEvent(
        reportId: reportId,
        actorId: actorId,
        actorRole: actorRole,
        previousStatus: previousStatus,
        newStatus: 'Assigned',
      );
    }

    final String reporterId = reportData['reporter_id'] as String? ?? '';
    if (reporterId.isNotEmpty) {
      await _notifications.notifyUser(
        userId: reporterId,
        title: 'Issue Assigned',
        body: 'Your reported issue has been assigned to a worker.',
        reportId: reportId,
      );
    }

    await _notifications.notifyUser(
      userId: workerId,
      title: 'New Task Assigned',
      body: 'A new issue has been assigned to you.',
      reportId: reportId,
    );
  }

  Future<void> updateStatus(
    String reportId,
    String status, {
    String actorId = 'system',
    String actorRole = 'system',
  }) async {
    final DocumentSnapshot<Map<String, dynamic>> reportDoc = await _reports
        .doc(reportId)
        .get();
    final Map<String, dynamic> data = reportDoc.data() ?? <String, dynamic>{};
    final String previousStatus = data['status'] as String? ?? 'Reported';

    if (previousStatus == status) {
      return;
    }

    final Map<String, dynamic> updates = <String, dynamic>{
      'status': status,
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (status == 'In Progress' && data['started_at'] == null) {
      updates['started_at'] = FieldValue.serverTimestamp();
    }

    if (status == 'Resolved') {
      updates['resolved_at'] = FieldValue.serverTimestamp();
      updates['completion_timestamp'] = FieldValue.serverTimestamp();
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
    if (status == 'Resolved' && reporterId.isNotEmpty) {
      await _notifications.notifyUser(
        userId: reporterId,
        title: 'Issue Resolved',
        body: 'Your reported issue has been resolved.',
        reportId: reportId,
      );
    }

    final String workerDocId = data['assigned_worker'] as String? ?? '';
    if (status == 'Resolved' && workerDocId.isNotEmpty) {
      await _applyWorkerCredibility(workerDocId, data);
    }
  }

  Future<void> uploadRepairImage({
    required String reportId,
    required File imageFile,
    required String workerId,
  }) async {
    final String fileName =
        'repairs/$workerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final TaskSnapshot snap = await _storage.ref(fileName).putFile(imageFile);
    final String url = await snap.ref.getDownloadURL();

    await _reports.doc(reportId).update(<String, dynamic>{
      'repair_image': url,
      'status': 'In Progress',
      'started_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _logReportEvent(
      reportId: reportId,
      actorId: workerId,
      actorRole: 'worker',
      previousStatus: 'Assigned',
      newStatus: 'In Progress',
    );
  }

  Future<void> markWorkerAttendance({
    required String reportId,
    required String workerId,
    required File selfieImage,
    required double latitude,
    required double longitude,
  }) async {
    final String fileName =
        'attendance/$workerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
    final TaskSnapshot snap = await _storage.ref(fileName).putFile(selfieImage);
    final String selfieUrl = await snap.ref.getDownloadURL();
    final DocumentReference<Map<String, dynamic>> topLevelAttendanceRef =
        _firestore.collection('attendance').doc();
    final DocumentReference<Map<String, dynamic>> reportAttendanceRef = _reports
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
  }

  Future<void> verifyRepair({
    required String reportId,
    required String userId,
    required bool isFixed,
  }) async {
    final DocumentReference<Map<String, dynamic>> ref = _reports.doc(reportId);
    final DocumentSnapshot<Map<String, dynamic>> snap = await ref.get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final String currentStatus = data['status'] as String? ?? 'Reported';

    if (isFixed) {
      await ref.update(<String, dynamic>{
        'verify_fixed_count': FieldValue.increment(1),
        'timestamp': FieldValue.serverTimestamp(),
      });
      await _updateCitizenReputation(userId: userId, approvedDelta: 1);
      return;
    }

    final int notFixed =
        ((data['verify_not_fixed_count'] as num?)?.toInt() ?? 0) + 1;
    final Map<String, dynamic> updates = <String, dynamic>{
      'verify_not_fixed_count': FieldValue.increment(1),
      'timestamp': FieldValue.serverTimestamp(),
    };

    if (currentStatus == 'Resolved' && notFixed >= 3) {
      updates['status'] = 'In Progress';
      updates['resolved_at'] = null;
      await _logReportEvent(
        reportId: reportId,
        actorId: userId,
        actorRole: 'citizen',
        previousStatus: 'Resolved',
        newStatus: 'In Progress',
      );
    }

    await ref.update(updates);
    await _updateCitizenReputation(userId: userId, rejectedDelta: 1);
  }

  Future<void> _updateCitizenReputation({
    required String userId,
    int approvedDelta = 0,
    int rejectedDelta = 0,
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

    await userRef.set(<String, dynamic>{
      'reports_approved': approved,
      'reports_rejected': rejected,
      'accuracy_score': double.parse(accuracy.toStringAsFixed(1)),
    }, SetOptions(merge: true));
  }

  Future<void> _applyPriorityEscalation(String reportId) async {
    final DocumentSnapshot<Map<String, dynamic>> snap = await _reports
        .doc(reportId)
        .get();
    final Map<String, dynamic> data = snap.data() ?? <String, dynamic>{};
    final int supportCount = (data['report_count'] as num?)?.toInt() ?? 1;

    String? escalatedPriority;
    if (supportCount > 50) {
      escalatedPriority = 'critical';
    } else if (supportCount > 25) {
      escalatedPriority = 'high';
    } else if (supportCount > 10) {
      escalatedPriority = 'medium';
    }

    if (escalatedPriority == null) {
      return;
    }

    final String currentPriority = (data['priority'] as String? ?? 'low')
        .toLowerCase();
    const Map<String, int> rank = <String, int>{
      'low': 0,
      'medium': 1,
      'high': 2,
      'critical': 3,
    };

    if ((rank[escalatedPriority] ?? 0) <= (rank[currentPriority] ?? 0)) {
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
    final Duration sla = switch (priority) {
      'high' || 'critical' => const Duration(hours: 6),
      'medium' => const Duration(hours: 24),
      _ => const Duration(hours: 48),
    };

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
      final Duration sla = switch (priority) {
        'high' || 'critical' => const Duration(hours: 6),
        'medium' => const Duration(hours: 24),
        _ => const Duration(hours: 48),
      };
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
}
