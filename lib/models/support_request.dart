import 'package:cloud_firestore/cloud_firestore.dart';

class SupportRequestModel {
  const SupportRequestModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    required this.status,
    required this.createdAt,
    this.adminReply,
    this.screenshotUrl,
  });

  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status;
  final DateTime createdAt;
  final String? adminReply;
  final String? screenshotUrl;

  factory SupportRequestModel.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final Map<String, dynamic> data = doc.data() ?? <String, dynamic>{};
    return SupportRequestModel(
      id: data['request_id'] as String? ?? doc.id,
      userId: data['user_id'] as String? ?? '',
      subject: data['subject'] as String? ?? 'Support Request',
      message: data['message'] as String? ?? '',
      status: data['status'] as String? ?? 'open',
      createdAt:
          (data['created_at'] as Timestamp?)?.toDate() ??
          (data['timestamp'] as Timestamp?)?.toDate() ??
          DateTime.now(),
      adminReply: data['admin_reply'] as String?,
      screenshotUrl: data['screenshot_url'] as String?,
    );
  }
}
