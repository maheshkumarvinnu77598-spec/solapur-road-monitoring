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

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      // ignore: avoid_print
      print('FCM foreground message: ${message.messageId}');
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
  }
}
