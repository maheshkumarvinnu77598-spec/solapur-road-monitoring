import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_model.dart';
import '../ui_theme/app_theme.dart';
import 'report_config.dart';
import 'report_detail_screen.dart';
import 'report_repository.dart';

class MyReportsScreen extends StatelessWidget {
  const MyReportsScreen({super.key, required this.repository});

  final ReportRepository repository;

  @override
  Widget build(BuildContext context) {
    final String reporterId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (reporterId.isEmpty) {
      return const Center(child: Text('Login required.'));
    }

    return StreamBuilder<List<ReportModel>>(
      stream: repository.myReports(reporterId),
      builder: (BuildContext context, AsyncSnapshot<List<ReportModel>> snapshot) {
        if (!snapshot.hasData) {
          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: 4,
            itemBuilder: (BuildContext context, int index) {
              return const _ReportCardSkeleton();
            },
          );
        }

        final List<ReportModel> reports = snapshot.data!;
        if (reports.isEmpty) {
          return const Center(child: Text('No reports yet.'));
        }

        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: reports.length,
          itemBuilder: (BuildContext context, int index) {
            final ReportModel report = reports[index];
            return Card(
              child: ListTile(
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => ReportDetailScreen(
                        report: report,
                        repository: repository,
                      ),
                    ),
                  );
                },
                leading: CircleAvatar(
                  backgroundColor: _statusColor(report.status).withAlpha(40),
                  child: Icon(
                    _iconForCategory(report.category),
                    color: _statusColor(report.status),
                    size: 20,
                  ),
                ),
                title: Text(report.category),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${report.status} • ${_timeAgo(report.timestamp)}'),
                    Text(
                      'Support: ${report.reportCount} • ${DateFormat('dd MMM, hh:mm a').format(report.timestamp)}',
                    ),
                  ],
                ),
                trailing: Chip(
                  label: Text(
                    report.priority.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: colorForPriority(report.priority),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'Reported':
      case 'Pending':
        return Colors.amber.shade700;
      case 'Assigned':
        return Colors.blue;
      case 'In Progress':
        return Colors.orange;
      case 'Resolved':
      case 'Fixed':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  IconData _iconForCategory(String category) {
    final match = issueCategories.where((i) => i.name == category);
    return match.isEmpty ? Icons.report_problem_outlined : match.first.icon;
  }

  String _timeAgo(DateTime time) {
    final Duration diff = DateTime.now().difference(time);
    if (diff.inDays > 0) {
      return '${diff.inDays}d ago';
    }
    if (diff.inHours > 0) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inMinutes}m ago';
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.status,
    required this.reportedAt,
    this.assignedAt,
    this.startedAt,
    this.resolvedAt,
  });

  final String status;
  final DateTime reportedAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? resolvedAt;

  @override
  Widget build(BuildContext context) {
    final int current = reportStatuses
        .indexOf(status)
        .clamp(0, reportStatuses.length - 1);
    final List<DateTime?> stageTimes = <DateTime?>[
      reportedAt,
      assignedAt,
      startedAt,
      resolvedAt,
    ];

    return Column(
      children: List<Widget>.generate(reportStatuses.length, (int i) {
        final bool complete = i <= current;
        final DateTime? stage = stageTimes[i];
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.circle,
                size: 10,
                color: complete ? AppPalette.primary : Colors.grey,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${reportStatuses[i]}${stage == null ? '' : ' • ${DateFormat('dd MMM hh:mm a').format(stage)}'}',
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _ReportCardSkeleton extends StatelessWidget {
  const _ReportCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, color: Colors.white),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 180, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
