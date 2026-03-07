import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../reporting/report_repository.dart';

class CitizenHomeScreen extends StatelessWidget {
  const CitizenHomeScreen({
    super.key,
    required this.repository,
    required this.onCreateReport,
  });

  final ReportRepository repository;
  final VoidCallback onCreateReport;

  @override
  Widget build(BuildContext context) {
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Solapur Road Monitoring',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Report city issues quickly and track progress live.',
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: onCreateReport,
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  label: const Text('Create New Report'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        StreamBuilder(
          stream: repository.myReports(userId),
          builder: (BuildContext context, AsyncSnapshot snapshot) {
            final int total = snapshot.hasData
                ? (snapshot.data as List).length
                : 0;
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Text('My total reports: $total'),
              ),
            );
          },
        ),
      ],
    );
  }
}
