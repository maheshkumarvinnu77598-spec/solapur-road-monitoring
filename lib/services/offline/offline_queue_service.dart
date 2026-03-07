import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../../models/offline_report.dart';

class OfflineQueueService {
  OfflineQueueService._();

  static final OfflineQueueService instance = OfflineQueueService._();
  Database? _db;

  Future<Database> _database() async {
    if (_db != null) {
      return _db!;
    }

    final dir = await getApplicationDocumentsDirectory();
    final String dbPath = p.join(dir.path, 'offline_reports.db');
    _db = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (Database db, int version) async {
        await db.execute('''
          CREATE TABLE offline_reports (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            report_id_local TEXT NOT NULL,
            reporter_id TEXT NOT NULL,
            category TEXT NOT NULL,
            description TEXT,
            image_path TEXT NOT NULL,
            latitude REAL NOT NULL,
            longitude REAL NOT NULL,
            created_at INTEGER NOT NULL,
            synced_flag INTEGER NOT NULL DEFAULT 0
          )
        ''');
      },
    );
    return _db!;
  }

  Future<int> enqueue(OfflineReport report) async {
    final Database db = await _database();
    return db.insert('offline_reports', report.toMap());
  }

  Future<List<OfflineReport>> pendingReports() async {
    final Database db = await _database();
    final List<Map<String, dynamic>> rows = await db.query(
      'offline_reports',
      where: 'synced_flag = ?',
      whereArgs: <Object>[0],
      orderBy: 'created_at ASC',
    );
    return rows.map(OfflineReport.fromMap).toList(growable: false);
  }

  Future<void> markSynced(int id) async {
    final Database db = await _database();
    await db.update(
      'offline_reports',
      <String, Object>{'synced_flag': 1},
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }

  Future<void> deleteById(int id) async {
    final Database db = await _database();
    await db.delete(
      'offline_reports',
      where: 'id = ?',
      whereArgs: <Object>[id],
    );
  }
}
