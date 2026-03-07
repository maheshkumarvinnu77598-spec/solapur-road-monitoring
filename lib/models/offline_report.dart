class OfflineReport {
  const OfflineReport({
    this.id,
    required this.localReportId,
    required this.reporterId,
    required this.category,
    required this.description,
    required this.imagePath,
    required this.latitude,
    required this.longitude,
    required this.createdAt,
    required this.syncedFlag,
  });

  final int? id;
  final String localReportId;
  final String reporterId;
  final String category;
  final String description;
  final String imagePath;
  final double latitude;
  final double longitude;
  final DateTime createdAt;
  final bool syncedFlag;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'id': id,
      'report_id_local': localReportId,
      'reporter_id': reporterId,
      'category': category,
      'description': description,
      'image_path': imagePath,
      'latitude': latitude,
      'longitude': longitude,
      'created_at': createdAt.millisecondsSinceEpoch,
      'synced_flag': syncedFlag ? 1 : 0,
    };
  }

  factory OfflineReport.fromMap(Map<String, dynamic> map) {
    return OfflineReport(
      id: map['id'] as int?,
      localReportId: map['report_id_local'] as String? ?? '',
      reporterId: map['reporter_id'] as String? ?? '',
      category: map['category'] as String? ?? 'Unknown',
      description: map['description'] as String? ?? '',
      imagePath: map['image_path'] as String? ?? '',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (map['created_at'] as num?)?.toInt() ?? 0,
      ),
      syncedFlag: (map['synced_flag'] as num?)?.toInt() == 1,
    );
  }
}
