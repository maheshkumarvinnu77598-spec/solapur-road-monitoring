import 'package:cloud_firestore/cloud_firestore.dart';

class DemoDataService {
  DemoDataService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> seedIfEmpty() async {
    try {
      final QuerySnapshot<Map<String, dynamic>> reports = await _firestore
          .collection('reports')
          .limit(1)
          .get();
      final QuerySnapshot<Map<String, dynamic>> workers = await _firestore
          .collection('workers')
          .limit(1)
          .get();

      if (reports.docs.isNotEmpty && workers.docs.isNotEmpty) {
        return;
      }

      final WriteBatch batch = _firestore.batch();
      final DateTime now = DateTime.now();

      final DocumentReference<Map<String, dynamic>> workerRef = _firestore
          .collection('workers')
          .doc('WRK001');
      batch.set(workerRef, <String, dynamic>{
        'name': 'Demo Worker',
        'worker_id': 'WRK001',
        'zone': 'Central Solapur',
        'role': 'Field Technician',
        'password': 'demo123',
        'email': 'worker.demo@solapur.app',
        'assigned_tasks': 2,
        'completed_tasks': 1,
        'pending_tasks': 1,
        'credibility_score': 84,
        'created_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (reports.docs.isEmpty) {
        final List<Map<String, dynamic>> sampleReports = <Map<String, dynamic>>[
          <String, dynamic>{
            'category': 'Pothole',
            'description':
                'Large pothole near the market road causing traffic slowdown.',
            'priority': 'high',
            'status': 'Reported',
            'assigned_worker_id': null,
            'assigned_worker_name': null,
            'latitude': 17.6599,
            'longitude': 75.9064,
            'reporter_id': 'demo_citizen',
            'report_count': 1,
            'duplicate_count': 1,
            'supporter_ids': <String>['demo_citizen'],
            'assigned_at': null,
            'started_at': null,
            'under_review_at': null,
            'resolved_at': null,
            'completion_timestamp': null,
            'sla_breach_flag': false,
            'verify_fixed_count': 0,
            'verify_not_fixed_count': 0,
            'timestamp': Timestamp.fromDate(
              now.subtract(const Duration(hours: 2)),
            ),
          },
          <String, dynamic>{
            'category': 'Water Logging',
            'description':
                'Drainage overflow causing water logging near the bus stand.',
            'priority': 'critical',
            'status': 'In Progress',
            'assigned_worker_id': 'WRK001',
            'assigned_worker_name': 'Demo Worker',
            'latitude': 17.6734,
            'longitude': 75.8948,
            'reporter_id': 'demo_citizen',
            'report_count': 1,
            'duplicate_count': 1,
            'supporter_ids': <String>['demo_citizen'],
            'assigned_at': Timestamp.fromDate(
              now.subtract(const Duration(hours: 4)),
            ),
            'started_at': Timestamp.fromDate(
              now.subtract(const Duration(hours: 3)),
            ),
            'under_review_at': null,
            'resolved_at': null,
            'completion_timestamp': null,
            'sla_breach_flag': false,
            'verify_fixed_count': 0,
            'verify_not_fixed_count': 0,
            'timestamp': Timestamp.fromDate(
              now.subtract(const Duration(hours: 4)),
            ),
          },
          <String, dynamic>{
            'category': 'Street Light Not Working',
            'description':
                'Street light is fixed but still awaiting admin closure in records.',
            'priority': 'medium',
            'status': 'Fixed',
            'assigned_worker_id': 'WRK001',
            'assigned_worker_name': 'Demo Worker',
            'latitude': 17.6481,
            'longitude': 75.9122,
            'reporter_id': 'demo_citizen',
            'report_count': 1,
            'duplicate_count': 1,
            'supporter_ids': <String>['demo_citizen'],
            'assigned_at': Timestamp.fromDate(
              now.subtract(const Duration(days: 1)),
            ),
            'started_at': Timestamp.fromDate(
              now.subtract(const Duration(hours: 20)),
            ),
            'under_review_at': Timestamp.fromDate(
              now.subtract(const Duration(hours: 14)),
            ),
            'resolved_at': Timestamp.fromDate(
              now.subtract(const Duration(hours: 10)),
            ),
            'completion_timestamp': Timestamp.fromDate(
              now.subtract(const Duration(hours: 10)),
            ),
            'sla_breach_flag': false,
            'verify_fixed_count': 1,
            'verify_not_fixed_count': 0,
            'timestamp': Timestamp.fromDate(
              now.subtract(const Duration(days: 1)),
            ),
          },
        ];

        for (final Map<String, dynamic> report in sampleReports) {
          final DocumentReference<Map<String, dynamic>> ref = _firestore
              .collection('reports')
              .doc();
          batch.set(ref, <String, dynamic>{
            'id': ref.id,
            'report_id': ref.id,
            'image_url': '',
            'location': GeoPoint(
              (report['latitude'] as num?)?.toDouble() ?? 0,
              (report['longitude'] as num?)?.toDouble() ?? 0,
            ),
            'repair_image': null,
            'repair_image_url': null,
            'image_hash': null,
            'image_captured_at': null,
            'ai_severity': null,
            'ai_confidence': null,
            'ai_boxes': const <Map<String, dynamic>>[],
            'created_at': report['timestamp'],
            'updated_at': report['timestamp'],
            ...report,
          });
        }
      }

      await batch.commit();
    } catch (_) {}
  }
}
