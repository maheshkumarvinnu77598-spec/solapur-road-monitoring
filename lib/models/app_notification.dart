import 'package:cloud_firestore/cloud_firestore.dart';

class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.read,
    required this.createdAt,
    required this.type,
    this.reportId,
  });

  final String id;
  final String userId;
  final String title;
  final String body;
  final String? reportId;
  final bool read;
  final DateTime createdAt;
  final String type;

  factory AppNotification.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return AppNotification(
      id: doc.id,
      userId: data['user_id'] as String? ?? '',
      title: data['title'] as String? ?? 'Notification',
      body: data['body'] as String? ?? '',
      reportId: data['report_id'] as String?,
      type: data['type'] as String? ?? 'Report Status Updated',
      read: (data['read'] as bool?) ?? (data['is_read'] as bool?) ?? false,
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
    );
  }
}
