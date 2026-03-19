import 'package:cloud_firestore/cloud_firestore.dart';

class DashboardReport {
  const DashboardReport({
    required this.id,
    required this.title,
    required this.description,
    required this.status,
    required this.priority,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.assignedWorkerId,
    required this.assignedWorkerName,
  });

  final String id;
  final String title;
  final String description;
  final String status;
  final String priority;
  final String category;
  final double latitude;
  final double longitude;
  final String assignedWorkerId;
  final String assignedWorkerName;

  String get displayTitle => title.isNotEmpty ? title : category;

  bool get hasValidLocation =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude.abs() <= 90 &&
      longitude.abs() <= 180 &&
      !(latitude == 0 && longitude == 0);

  factory DashboardReport.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    final GeoPoint? location = data['location'] as GeoPoint?;
    final String category = data['category'] as String? ?? 'Issue';
    return DashboardReport(
      id: doc.id,
      title: data['title'] as String? ?? category,
      description: data['description'] as String? ?? '',
      status: data['status'] as String? ?? 'Reported',
      priority: (data['priority'] as String? ?? 'low').toLowerCase(),
      category: category,
      latitude:
          location?.latitude ?? (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude:
          location?.longitude ?? (data['longitude'] as num?)?.toDouble() ?? 0,
      assignedWorkerId:
          data['assigned_worker_id'] as String? ??
          data['assigned_worker'] as String? ??
          '',
      assignedWorkerName: data['assigned_worker_name'] as String? ?? '',
    );
  }
}

class DashboardWorker {
  const DashboardWorker({
    required this.id,
    required this.docId,
    required this.sourceCollection,
    required this.name,
    required this.zone,
    required this.role,
    required this.credibilityScore,
    required this.activeTasks,
  });

  final String id;
  final String docId;
  final String sourceCollection;
  final String name;
  final String zone;
  final String role;
  final double credibilityScore;
  final int activeTasks;

  factory DashboardWorker.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc, {
    required String sourceCollection,
  }) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return DashboardWorker(
      id: data['worker_id'] as String? ?? doc.id,
      docId: doc.id,
      sourceCollection: sourceCollection,
      name:
          data['name'] as String? ??
          data['worker_name'] as String? ??
          data['displayName'] as String? ??
          data['email'] as String? ??
          doc.id,
      zone: data['zone'] as String? ?? '-',
      role: data['role'] as String? ?? 'Worker',
      credibilityScore:
          (data['credibility_score'] as num?)?.toDouble() ??
          (data['credibility'] as num?)?.toDouble() ??
          (data['credibilityScore'] as num?)?.toDouble() ??
          0,
      activeTasks:
          (data['pending_tasks'] as num?)?.toInt() ??
          (data['active_tasks'] as num?)?.toInt() ??
          0,
    );
  }
}

class FirestoreService {
  FirestoreService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<DashboardReport>> reportsStream() {
    return _firestore
        .collection('reports')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map(DashboardReport.fromDoc)
              .toList(growable: false),
        );
  }

  Stream<List<DashboardWorker>> workersStream() {
    final Stream<List<DashboardWorker>> primary = _firestore
        .collection('workers')
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snapshot) => snapshot.docs
              .map((DocumentSnapshot<Map<String, dynamic>> doc) {
                return DashboardWorker.fromDoc(
                  doc,
                  sourceCollection: 'workers',
                );
              })
              .toList(growable: false),
        );

    return primary.asyncMap((List<DashboardWorker> workers) async {
      if (workers.isNotEmpty) {
        return workers;
      }
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _firestore
          .collection('users')
          .where('role', isEqualTo: 'worker')
          .get();
      return snapshot.docs
          .map((DocumentSnapshot<Map<String, dynamic>> doc) {
            return DashboardWorker.fromDoc(doc, sourceCollection: 'users');
          })
          .toList(growable: false);
    });
  }

  Future<void> assignWorker({
    required String reportId,
    required DashboardWorker worker,
  }) {
    return _firestore
        .collection('reports')
        .doc(reportId)
        .update(<String, dynamic>{
          'assigned_worker': worker.id,
          'assigned_worker_id': worker.id,
          'assigned_worker_name': worker.name,
          'status': 'Assigned',
          'updated_at': FieldValue.serverTimestamp(),
        });
  }

  Future<void> markFixed({required String reportId}) async {
    try {
      await FirebaseFirestore.instance
          .collection('reports')
          .doc(reportId)
          .update(<String, dynamic>{
            'status': 'Fixed',
            'updated_at': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      // ignore: avoid_print
      print('ERROR MARKING FIXED: $e');
      rethrow;
    }
  }

  Future<void> updateStatus({
    required String reportId,
    required String status,
  }) async {
    await _firestore.collection('reports').doc(reportId).update(
      <String, dynamic>{
        'status': status,
        'updated_at': FieldValue.serverTimestamp(),
      },
    );
  }

  Future<void> deleteWorker({required DashboardWorker worker}) {
    return _firestore
        .collection(worker.sourceCollection)
        .doc(worker.docId)
        .delete();
  }

  Future<void> createWorker({
    required String workerId,
    required String name,
    required String zone,
    required String role,
    required String password,
  }) {
    return _firestore.collection('workers').doc(workerId).set(<String, dynamic>{
      'worker_id': workerId,
      'name': name,
      'zone': zone,
      'role': role,
      'password': password,
      'credibility': 100,
      'credibility_score': 100,
      'active_tasks': 0,
      'created_at': FieldValue.serverTimestamp(),
    });
  }
}
