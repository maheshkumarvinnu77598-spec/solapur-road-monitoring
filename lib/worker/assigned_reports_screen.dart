import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/report_model.dart';
import '../reporting/report_config.dart';
import '../utils/priority_utils.dart';
import '../utils/resilient_ui.dart';
import 'report_detail_screen.dart';

class AssignedReportsScreen extends StatelessWidget {
  const AssignedReportsScreen({
    super.key,
    required this.workerId,
    required this.firestore,
  });

  final String workerId;
  final FirebaseFirestore firestore;

  Future<void> _openMaps(
    BuildContext context,
    double latitude,
    double longitude,
  ) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$latitude,$longitude',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Assigned Reports')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: firestore.collection('reports').snapshots(),
        builder:
            (
              BuildContext context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.hasError) {
                return const Center(
                  child: Text('Failed to load assigned reports.'),
                );
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final List<ReportModel> reports = snapshot.data!.docs
                  .map(ReportModel.fromDoc)
                  .where(
                    (ReportModel report) => report.assignedWorker == workerId,
                  )
                  .toList(growable: true);

              reports.sort((a, b) {
                final int aRank = priorityRank[a.priority.toLowerCase()] ?? 0;
                final int bRank = priorityRank[b.priority.toLowerCase()] ?? 0;
                return bRank.compareTo(aRank);
              });

              if (reports.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: DemoEmptyState(
                      message: 'No tasks assigned',
                      icon: Icons.assignment_outlined,
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: reports.length,
                itemBuilder: (BuildContext context, int index) {
                  final ReportModel report = reports[index];
                  final Color priorityColor = colorForPriority(report.priority);

                  return Card(
                    elevation: 3,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    margin: const EdgeInsets.only(bottom: 16),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            report.category,
                            style: textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: <Widget>[
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
                              Chip(label: Text('Status: ${report.status}')),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            report.description,
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Location: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                            style: textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: <Widget>[
                              FilledButton.tonalIcon(
                                onPressed: () => Navigator.of(context).push(
                                  MaterialPageRoute<void>(
                                    builder: (BuildContext context) =>
                                        ReportDetailScreen(
                                          reportId: report.id,
                                          workerId: workerId,
                                          firestore: firestore,
                                        ),
                                  ),
                                ),
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('View Details'),
                              ),
                              FilledButton.icon(
                                onPressed: () => _openMaps(
                                  context,
                                  report.latitude,
                                  report.longitude,
                                ),
                                icon: const Icon(Icons.map_outlined),
                                label: const Text('Open in Maps'),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
      ),
    );
  }
}
