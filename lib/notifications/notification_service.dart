import 'package:cloud_firestore/cloud_firestore.dart';

class NotificationService {
  NotificationService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<void> notifyUser({
    required String userId,
    required String title,
    required String body,
    required String type,
    String? reportId,
  }) async {
    try {
      await _firestore.collection('notifications').add(<String, dynamic>{
        'user_id': userId,
        'title': title,
        'body': body,
        'type': type,
        'report_id': reportId,
        'read': false,
        'is_read': false,
        'created_at': FieldValue.serverTimestamp(),
        'timestamp': FieldValue.serverTimestamp(),
      });
    } on FirebaseException {
      rethrow;
    }
  }
}
