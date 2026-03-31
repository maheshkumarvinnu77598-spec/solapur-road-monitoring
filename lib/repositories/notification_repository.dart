import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_notification.dart';

class NotificationRepository {
  NotificationRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Stream<List<AppNotification>> streamForUser(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
<<<<<<< HEAD
        .orderBy('timestamp', descending: true)
=======
        .orderBy('created_at', descending: true)
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(AppNotification.fromDoc).toList(growable: false),
        );
  }

  Stream<int> unreadCount(String userId) {
    return _firestore
        .collection('notifications')
        .where('user_id', isEqualTo: userId)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) => snap.docs.where((doc) {
            final data = doc.data();
            final bool read =
                (data['read'] as bool?) ?? (data['is_read'] as bool?) ?? false;
            return !read;
          }).length,
        );
  }

  Future<void> markRead(String notificationId) {
    return _firestore.collection('notifications').doc(notificationId).set(
<<<<<<< HEAD
      <String, dynamic>{'read': true, 'is_read': true},
=======
      <String, dynamic>{
        'read': true,
        'is_read': true,
        'updated_at': FieldValue.serverTimestamp(),
      },
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      SetOptions(merge: true),
    );
  }
}
