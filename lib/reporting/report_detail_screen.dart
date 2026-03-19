import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../models/report_model.dart';
import '../utils/priority_utils.dart';
import '../utils/resilient_ui.dart';
import 'my_reports_screen.dart';
import 'report_repository.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.repository,
  });

  final ReportModel report;
  final ReportRepository repository;

  @override
  Widget build(BuildContext context) {
    final bool hasCoordinates = report.hasValidCoordinates;
    return Scaffold(
      appBar: AppBar(title: Text(report.category)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (report.imageUrl.isNotEmpty)
            _aiImagePreview(report: report)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 12),
          _headCard(context),
          if (hasCoordinates) ...<Widget>[
            const SizedBox(height: 10),
            _locationMap(),
          ],
          if ((report.repairImage ?? '').isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            const Text(
              'Repair Proof',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            DemoNetworkImage(imageUrl: report.repairImage!, height: 180),
          ],
          const SizedBox(height: 12),
          const Text(
            'Progress Timeline',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          StatusTimeline(
            status: report.status,
            reportedAt: report.timestamp,
            assignedAt: report.assignedAt,
            startedAt: report.startedAt,
            underReviewAt: report.underReviewAt,
            completionTimestamp: report.completionTimestamp,
          ),
        ],
      ),
    );
  }

  Widget _headCard(BuildContext context) {
    final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              report.description.isEmpty
                  ? 'No description'
                  : report.description,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(label: Text('Status: ${report.status}')),
                Chip(
                  backgroundColor: colorForPriority(report.priority),
                  label: Text(
                    report.priority.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
                Chip(label: Text('Support: ${report.reportCount}')),
              ],
            ),
            if (report.aiConfidence != null ||
                report.aiSeverity != null) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                'AI: ${report.aiSeverity ?? '-'} • ${((report.aiConfidence ?? 0) * 100).toStringAsFixed(0)}% confidence',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
            if ((report.repairImage ?? '').isNotEmpty &&
                currentUserId == report.reporterId &&
                (report.status == 'Under Review' ||
                    report.status == 'Fixed')) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                'Repair Verification',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  FilledButton.icon(
                    onPressed: () async {
                      try {
                        await repository.verifyRepair(
                          reportId: report.id,
                          userId: currentUserId,
                          isFixed: true,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Repair confirmed. Thank you.'),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not verify repair right now.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.verified_outlined),
                    label: const Text('Issue Fixed'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () async {
                      try {
                        await repository.verifyRepair(
                          reportId: report.id,
                          userId: currentUserId,
                          isFixed: false,
                        );
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Issue reopened for reinspection.'),
                          ),
                        );
                      } catch (_) {
                        if (!context.mounted) {
                          return;
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update issue right now.'),
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.report_problem_outlined),
                    label: const Text('Not Fixed'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationMap() {
    return Card(
      child: DemoMapPreview(
        latitude: report.latitude,
        longitude: report.longitude,
        height: 180,
        borderRadius: BorderRadius.circular(14),
      ),
    );
  }

  Widget _aiImagePreview({required ReportModel report}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: <Widget>[
              DemoNetworkImage(imageUrl: report.imageUrl, height: 220),
              ...report.aiBoxes.map((box) {
                final double w = constraints.maxWidth;
                final double scale = w / 300;
                return Positioned(
                  left: box.x * scale,
                  top: box.y * scale,
                  width: box.width * scale,
                  height: box.height * scale,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.redAccent, width: 2),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                );
              }),
            ],
          ),
        );
      },
    );
  }
}
