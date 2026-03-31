import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../reporting/report_repository.dart';

<<<<<<< HEAD
class CitizenHomeScreen extends StatelessWidget {
=======
class CitizenHomeScreen extends StatefulWidget {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  const CitizenHomeScreen({
    super.key,
    required this.repository,
    required this.onCreateReport,
<<<<<<< HEAD
=======
    required this.onOpenAnalytics,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  });

  final ReportRepository repository;
  final VoidCallback onCreateReport;
<<<<<<< HEAD

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
=======
  final VoidCallback onOpenAnalytics;

  @override
  State<CitizenHomeScreen> createState() => _CitizenHomeScreenState();
}

class _CitizenHomeScreenState extends State<CitizenHomeScreen> {
  late final Stream<List<dynamic>> _myReportsStream;

  @override
  void initState() {
    super.initState();
    final String userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    _myReportsStream = widget.repository.myReports(userId);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                    onPressed: widget.onCreateReport,
                    icon: const Icon(Icons.add_photo_alternate_outlined),
                    label: const Text('Create New Report'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: widget.onOpenAnalytics,
                    icon: const Icon(Icons.analytics_outlined),
                    label: const Text('City Analytics'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder(
            stream: _myReportsStream,
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
      ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    );
  }
}
