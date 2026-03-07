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
        .orderBy('timestamp', descending: true)
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
      <String, dynamic>{'read': true, 'is_read': true},
      SetOptions(merge: true),
    );
  }
}
