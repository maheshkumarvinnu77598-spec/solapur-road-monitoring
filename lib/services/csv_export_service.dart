import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:csv/csv.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class CsvExportService {
  CsvExportService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<File> exportReportsCsv() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('reports')
        .orderBy('timestamp', descending: true)
        .get();

    final List<List<dynamic>> rows = <List<dynamic>>[
      <dynamic>[
        'report_id',
        'category',
        'priority',
        'status',
        'reporter_id',
        'assigned_worker',
        'latitude',
        'longitude',
        'created_at',
        'resolved_at',
      ],
    ];

    for (final doc in snap.docs) {
      final data = doc.data();
      rows.add(<dynamic>[
        data['report_id'] ?? doc.id,
        data['category'] ?? '',
        data['priority'] ?? '',
        data['status'] ?? '',
        data['reporter_id'] ?? '',
        data['assigned_worker'] ?? '',
        data['latitude'] ?? '',
        data['longitude'] ?? '',
        (data['timestamp'] as Timestamp?)?.toDate().toIso8601String() ?? '',
        (data['resolved_at'] as Timestamp?)?.toDate().toIso8601String() ?? '',
      ]);
    }

    return _writeCsv(
      'reports_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  Future<File> exportWorkersCsv() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('workers')
        .orderBy('worker_id')
        .get();

    final List<List<dynamic>> rows = <List<dynamic>>[
      <dynamic>[
        'worker_doc_id',
        'worker_id',
        'name',
        'zone',
        'credibility_score',
        'completed_tasks',
        'pending_tasks',
      ],
    ];

    for (final doc in snap.docs) {
      final data = doc.data();
      rows.add(<dynamic>[
        doc.id,
        data['worker_id'] ?? '',
        data['name'] ?? '',
        data['zone'] ?? '',
        data['credibility_score'] ?? 0,
        data['completed_tasks'] ?? 0,
        data['pending_tasks'] ?? 0,
      ]);
    }

    return _writeCsv(
      'workers_export_${DateTime.now().millisecondsSinceEpoch}.csv',
      rows,
    );
  }

  Future<File> _writeCsv(String fileName, List<List<dynamic>> rows) async {
    final String csv = const ListToCsvConverter().convert(rows);
    final Directory dir = await getTemporaryDirectory();
    final File file = File(p.join(dir.path, fileName));
    return file.writeAsString(csv);
  }
}
