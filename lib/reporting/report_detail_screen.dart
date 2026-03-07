import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/report_model.dart';
import '../services/analytics_service.dart';
import 'my_reports_screen.dart';
import 'report_config.dart';
import 'report_repository.dart';

class ReportDetailScreen extends StatelessWidget {
  const ReportDetailScreen({
    super.key,
    required this.report,
    required this.repository,
  });

  final ReportModel report;
  final ReportRepository repository;
  static final AnalyticsService _analytics = AnalyticsService.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(report.category)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (report.imageUrl.isNotEmpty)
            _aiImagePreview(report: report)
          else
            const SizedBox.shrink(),
          const SizedBox(height: 12),
          _headCard(context),
          const SizedBox(height: 10),
          _locationMap(),
          if ((report.repairImage ?? '').isNotEmpty) ...[
            const SizedBox(height: 10),
            const Text(
              'Repair Proof',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                report.repairImage!,
                height: 180,
                fit: BoxFit.cover,
              ),
            ),
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
            resolvedAt: report.resolvedAt,
          ),
          if (report.status == 'Resolved') ...[
            const SizedBox(height: 12),
            const Text(
              'Repair Verification',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: () => _verify(context, true),
                  icon: const Icon(Icons.check_circle_outline),
                  label: const Text('Issue Fixed'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _verify(context, false),
                  icon: const Icon(Icons.error_outline),
                  label: const Text('Issue Not Fixed'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              'Fixed votes: ${report.verifyFixedCount} • Not fixed votes: ${report.verifyNotFixedCount}',
            ),
          ],
        ],
      ),
    );
  }

  Widget _headCard(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.description.isEmpty
                  ? 'No description'
                  : report.description,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
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
            if (report.aiConfidence != null || report.aiSeverity != null) ...[
              const SizedBox(height: 8),
              Text(
                'AI: ${report.aiSeverity ?? '-'} • ${((report.aiConfidence ?? 0) * 100).toStringAsFixed(0)}% confidence',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _locationMap() {
    return Card(
      child: SizedBox(
        height: 180,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: GoogleMap(
            initialCameraPosition: CameraPosition(
              target: LatLng(report.latitude, report.longitude),
              zoom: 15,
            ),
            markers: {
              Marker(
                markerId: MarkerId(report.id),
                position: LatLng(report.latitude, report.longitude),
              ),
            },
            zoomControlsEnabled: false,
            myLocationButtonEnabled: false,
          ),
        ),
      ),
    );
  }

  Widget _aiImagePreview({required ReportModel report}) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Stack(
            children: [
              Image.network(
                report.imageUrl,
                height: 220,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
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

  Future<void> _verify(BuildContext context, bool isFixed) async {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    if (userId.isEmpty) {
      return;
    }
    try {
      await repository.verifyRepair(
        reportId: report.id,
        userId: userId,
        isFixed: isFixed,
      );
      unawaited(
        _analytics.logRepairVerified(reportId: report.id, isFixed: isFixed),
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isFixed ? 'Thanks for verification.' : 'Issue flagged.',
          ),
        ),
      );
    } catch (_) {
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not submit verification right now.'),
        ),
      );
    }
  }
}
