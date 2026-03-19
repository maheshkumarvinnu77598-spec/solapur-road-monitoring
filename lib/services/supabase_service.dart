import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  final SupabaseClient client = Supabase.instance.client;

  Future<String?> uploadAttendanceImage({
    required File file,
    required String workerId,
  }) async {
    try {
      if (!await file.exists()) {
        return null;
      }
      final String fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final String path = 'attendance/$workerId/$fileName';

      await client.storage.from('attendance').upload(path, file);

      final String publicUrl = client.storage
          .from('attendance')
          .getPublicUrl(path);

      return publicUrl;
    } catch (e) {
      return null;
    }
  }
}
