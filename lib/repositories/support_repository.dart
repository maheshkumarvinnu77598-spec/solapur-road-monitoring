import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/support_request.dart';

class SupportRepository {
  SupportRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('support_requests');

  Stream<List<SupportRequestModel>> streamForUser(String userId) {
    return _requests
        .where('user_id', isEqualTo: userId)
        .orderBy('created_at', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map(SupportRequestModel.fromDoc)
              .toList(growable: false),
        );
  }

  Future<String> submitRequest({
    required String userId,
    required String subject,
    required String message,
    File? screenshot,
  }) async {
    String? screenshotUrl;
    if (screenshot != null && await screenshot.exists()) {
      final String path =
          'support_requests/$userId/${DateTime.now().millisecondsSinceEpoch}.jpg';
      final SupabaseClient supabase = Supabase.instance.client;
      await supabase.storage
          .from('report-images')
          .upload(
            path,
            screenshot,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );
      screenshotUrl = supabase.storage.from('report-images').getPublicUrl(path);
    }

    final DocumentReference<Map<String, dynamic>> ref = _requests.doc();
    await ref.set(<String, dynamic>{
      'request_id': ref.id,
      'user_id': userId,
      'subject': subject,
      'message': message,
      'status': 'open',
      'created_at': FieldValue.serverTimestamp(),
      'timestamp': FieldValue.serverTimestamp(),
      'admin_reply': null,
      'screenshot_url': screenshotUrl,
    });
    return ref.id;
  }
}
