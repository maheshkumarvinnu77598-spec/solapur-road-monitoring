import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> notifyUser({
    required String userId,
    required String title,
    required String body,
    String? reportId,
  }) async {
    await _firestore.collection('notifications').add(<String, dynamic>{
      'user_id': userId,
      'title': title,
      'body': body,
      'report_id': reportId,
      'read': false,
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}
