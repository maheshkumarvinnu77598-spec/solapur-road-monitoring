import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../models/app_notification.dart';
import '../../repositories/notification_repository.dart';
import '../../reporting/report_detail_screen.dart';
import '../../reporting/report_repository.dart';

class NotificationsInboxScreen extends StatelessWidget {
  const NotificationsInboxScreen({
    super.key,
    required this.notificationRepository,
    required this.reportRepository,
  });

  final NotificationRepository notificationRepository;
  final ReportRepository reportRepository;

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Notifications')),
        body: const Center(child: Text('Login required.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: Column(
        children: <Widget>[
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: notificationRepository.streamForUser(userId),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<List<AppNotification>> snap,
                  ) {
                    if (snap.hasError) {
                      return const Center(
                        child: Text(
                          'Unable to load notifications right now. Please try again.',
                        ),
                      );
                    }
                    if (!snap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final List<AppNotification> notifications = snap.data!;
                    if (notifications.isEmpty) {
                      return const Center(child: Text('No notifications'));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.all(12),
                      itemCount: notifications.length,
                      itemBuilder: (BuildContext context, int index) {
                        final AppNotification notification =
                            notifications[index];
                        final String title = notification.title;
                        final String message = notification.body;
                        return GestureDetector(
                          onTap: () async {
                            try {
                              await notificationRepository.markRead(
                                notification.id,
                              );
                              if (notification.reportId == null ||
                                  notification.reportId!.isEmpty) {
                                return;
                              }
                              final report = await reportRepository
                                  .getReportById(notification.reportId!);
                              if (!context.mounted || report == null) {
                                return;
                              }
                              Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => ReportDetailScreen(
                                    report: report,
                                    repository: reportRepository,
                                  ),
                                ),
                              );
                            } catch (_) {
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Unable to open this notification right now.',
                                  ),
                                ),
                              );
                            }
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            margin: const EdgeInsets.symmetric(vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Icon(
                                  notification.read
                                      ? Icons.notifications_none_outlined
                                      : Icons.notifications_active,
                                  color: notification.read ? null : Colors.red,
                                  size: 22,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        title,
                                        style: TextStyle(
                                          fontWeight: notification.read
                                              ? FontWeight.w500
                                              : FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(message),
                                      const SizedBox(height: 6),
                                      Text(
                                        DateFormat(
                                          'dd MMM, hh:mm a',
                                        ).format(notification.createdAt),
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    );
                  },
            ),
          ),
        ],
      ),
    );
  }
}
