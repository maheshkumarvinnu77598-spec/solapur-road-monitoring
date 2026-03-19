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
      final DocumentReference<Map<String, dynamic>> docRef = _firestore
          .collection('notifications')
          .doc();
      await docRef.set(<String, dynamic>{
        'id': docRef.id,
        'user_id': userId,
        'title': title,
        'message': body,
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
