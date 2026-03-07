import 'package:flutter/material.dart';

class ReportConfirmationScreen extends StatelessWidget {
  const ReportConfirmationScreen({
    super.key,
    required this.reportId,
    required this.category,
    required this.status,
    required this.priority,
    required this.latitude,
    required this.longitude,
    required this.onViewReport,
  });

  final String reportId;
  final String category;
  final String status;
  final String priority;
  final double latitude;
  final double longitude;
  final VoidCallback onViewReport;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Report Submitted')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.check_circle, color: Colors.green, size: 56),
                const SizedBox(height: 8),
                const Text(
                  'Report Submitted Successfully',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Text('Report ID: $reportId'),
                Text('Category: $category'),
                Text('Status: $status'),
                Text('Priority: $priority'),
                Text(
                  'Location: ${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                ),
                const Spacer(),
                FilledButton(
                  onPressed: onViewReport,
                  child: const Text('View Report'),
                ),
                const SizedBox(height: 8),
                FilledButton.tonal(
                  onPressed: () =>
                      Navigator.popUntil(context, (r) => r.isFirst),
                  child: const Text('Return to Home'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
