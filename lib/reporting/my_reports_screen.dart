import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/report_model.dart';
import '../ui_theme/app_theme.dart';
import '../utils/priority_utils.dart';
import '../utils/resilient_ui.dart';
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
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load reports right now. Please try again.'),
          );
        }
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
          return const Padding(
            padding: EdgeInsets.all(16),
            child: DemoEmptyState(
              message: 'No reports available',
              icon: Icons.inbox_outlined,
            ),
          );
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 180),
          child: ListView.builder(
            key: ValueKey<int>(reports.length),
            padding: const EdgeInsets.all(12),
            itemCount: reports.length,
            itemBuilder: (BuildContext context, int index) {
              final ReportModel report = reports[index];
              final Color priorityColor = colorForPriority(report.priority);
              return Card(
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
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
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          height: 72,
                          width: 72,
                          child: DemoNetworkImage(
                            imageUrl: report.imageUrl,
                            height: 72,
                            width: 72,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                report.category,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${report.status} • ${DateFormat('dd MMM, hh:mm a').format(report.timestamp)}',
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Location: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.bodyMedium,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Chip(
                          label: Text(
                            report.priority.toUpperCase(),
                            style: TextStyle(
                              color:
                                  ThemeData.estimateBrightnessForColor(
                                        priorityColor,
                                      ) ==
                                      Brightness.dark
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          ),
                          backgroundColor: priorityColor,
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class StatusTimeline extends StatelessWidget {
  const StatusTimeline({
    super.key,
    required this.status,
    required this.reportedAt,
    this.assignedAt,
    this.startedAt,
    this.underReviewAt,
    this.completionTimestamp,
  });

  final String status;
  final DateTime reportedAt;
  final DateTime? assignedAt;
  final DateTime? startedAt;
  final DateTime? underReviewAt;
  final DateTime? completionTimestamp;

  @override
  Widget build(BuildContext context) {
    final int current = reportStatuses
        .indexOf(status)
        .clamp(0, reportStatuses.length - 1);
    final List<DateTime?> stageTimes = <DateTime?>[
      reportedAt,
      assignedAt,
      startedAt,
      underReviewAt,
      completionTimestamp,
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
    final Color skeleton = Theme.of(
      context,
    ).colorScheme.surface.withValues(alpha: 0.8);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              height: 36,
              width: 36,
              decoration: BoxDecoration(
                color: skeleton,
                borderRadius: BorderRadius.circular(18),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(height: 12, color: skeleton),
                  const SizedBox(height: 8),
                  Container(height: 10, width: 180, color: skeleton),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
