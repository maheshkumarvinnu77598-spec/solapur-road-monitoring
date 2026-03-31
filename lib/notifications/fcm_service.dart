import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../models/app_user.dart';

class FcmService {
  FcmService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Future<void> initialize() async {
    await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    final String? token = await _messaging.getToken();
    await _storeTokenForCurrentUser(token);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
      await _persistForegroundMessage(message);
    });

    _messaging.onTokenRefresh.listen(_storeTokenForCurrentUser);
  }

  Future<void> refreshTokenForUser(User user) async {
    final String? token = await _messaging.getToken();
    await _storeToken(user.uid, token);
  }

  Future<void> syncTokenForAppUser(AppUser appUser) async {
    final String? token = await _messaging.getToken();
    if (token == null || token.isEmpty) {
      return;
    }

    if (appUser.role == UserRole.worker) {
      await _firestore.collection('workers').doc(appUser.uid).set(
        <String, dynamic>{
          'fcm_tokens': FieldValue.arrayUnion(<String>[token]),
        },
        SetOptions(merge: true),
      );
      return;
    }
    await _storeToken(appUser.uid, token);
  }

  Future<void> _storeTokenForCurrentUser(String? token) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    await _storeToken(user.uid, token);
  }

  Future<void> _storeToken(String userId, String? token) async {
    if (token == null || token.isEmpty) {
      return;
    }
    await _firestore.collection('users').doc(userId).set(<String, dynamic>{
      'fcm_tokens': FieldValue.arrayUnion(<String>[token]),
      'last_token_sync_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await _firestore.collection('workers').doc(userId).set(<String, dynamic>{
      'fcm_tokens': FieldValue.arrayUnion(<String>[token]),
      'last_token_sync_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> _persistForegroundMessage(RemoteMessage message) async {
    final User? user = _auth.currentUser;
    if (user == null) {
      return;
    }
    final String title =
        message.notification?.title ?? (message.data['title'] as String? ?? '');
    final String body =
        message.notification?.body ?? (message.data['body'] as String? ?? '');
    if (title.isEmpty && body.isEmpty) {
      return;
    }

    final String? reportId = message.data['report_id'] as String?;
    final String type =
        message.data['type'] as String? ?? 'Report Status Updated';
    final String docId = message.messageId == null || message.messageId!.isEmpty
        ? 'local-${DateTime.now().millisecondsSinceEpoch}'
        : message.messageId!;

    await _firestore
        .collection('notifications')
        .doc(docId)
        .set(<String, dynamic>{
          'user_id': user.uid,
          'title': title,
          'body': body,
          'report_id': reportId,
          'type': type,
          'read': false,
          'is_read': false,
          'created_at': FieldValue.serverTimestamp(),
          'timestamp': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }
}
