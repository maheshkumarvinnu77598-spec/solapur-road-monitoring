import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/app_user.dart';
import '../models/report_model.dart';
import '../reporting/report_config.dart';
import '../reporting/report_repository.dart';
import '../services/analytics_service.dart';
import '../services/haptic_service.dart';

class WorkerDashboardScreen extends StatefulWidget {
  const WorkerDashboardScreen({
    super.key,
    required this.worker,
    required this.firestore,
  });

  final AppUser worker;
  final FirebaseFirestore firestore;

  @override
  State<WorkerDashboardScreen> createState() => _WorkerDashboardScreenState();
}

class _WorkerDashboardScreenState extends State<WorkerDashboardScreen> {
  int _index = 0;
  late final ReportRepository _repository;
  final AnalyticsService _analytics = AnalyticsService.instance;

  @override
  void initState() {
    super.initState();
    _repository = ReportRepository(firestore: widget.firestore);
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> tabs = <Widget>[
      _taskList(completed: false),
      _taskList(completed: true),
      _profile(),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Worker Dashboard')),
      body: tabs[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (int i) => setState(() => _index = i),
        destinations: const <NavigationDestination>[
          NavigationDestination(
            icon: Icon(Icons.assignment_outlined),
            label: 'Assigned',
          ),
          NavigationDestination(
            icon: Icon(Icons.task_alt_outlined),
            label: 'Completed',
          ),
          NavigationDestination(
            icon: Icon(Icons.badge_outlined),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  Widget _taskList({required bool completed}) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: widget.firestore
          .collection('reports')
          .where('assigned_worker', isEqualTo: widget.worker.uid)
          .snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return const Center(
                child: Text(
                  'Unable to load tasks right now. Check your network and try again.',
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<ReportModel> reports = snapshot.data!.docs
                .map(ReportModel.fromDoc)
                .where(
                  (ReportModel r) => completed
                      ? r.status == 'Fixed'
                      : (r.status == 'Assigned' ||
                            r.status == 'In Progress' ||
                            r.status == 'Under Review'),
                )
                .toList(growable: false);

            final int assignedCount = reports
                .where((ReportModel r) => r.status == 'Assigned')
                .length;
            final int underReviewCount = reports
                .where((ReportModel r) => r.status == 'Under Review')
                .length;
            final int completeCount = reports
                .where((ReportModel r) => r.status == 'Fixed')
                .length;
            final int slaWarnings = reports
                .where((ReportModel r) => !completed && _isNearSlaBreach(r))
                .length;

            if (reports.isEmpty && completed) {
              return const Center(child: Text('No completed tasks.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: reports.length + 1,
              itemBuilder: (BuildContext context, int index) {
                if (index == 0) {
                  return Column(
                    children: <Widget>[
                      _headerCards(
                        assignedCount,
                        completeCount,
                        underReviewCount,
                        slaWarnings,
                      ),
                      if (reports.isEmpty && !completed)
                        const Padding(
                          padding: EdgeInsets.only(top: 20),
                          child: Center(child: Text('No assigned tasks.')),
                        ),
                    ],
                  );
                }
                return _taskCard(reports[index - 1]);
              },
            );
          },
    );
  }

  Widget _headerCards(
    int assigned,
    int completed,
    int underReview,
    int slaWarnings,
  ) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: widget.firestore
          .collection('workers')
          .doc(widget.worker.uid)
          .get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            final String photo = data['photo_url'] as String? ?? '';
            return Column(
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: <Widget>[
                        CircleAvatar(
                          radius: 28,
                          backgroundImage: photo.isNotEmpty
                              ? NetworkImage(photo)
                              : null,
                          child: photo.isEmpty
                              ? const Icon(Icons.person_outline)
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              Text(
                                data['name'] as String? ??
                                    widget.worker.name ??
                                    '-',
                              ),
                              Text(
                                'Worker ID: ${data['worker_id'] ?? widget.worker.uid}',
                              ),
                              Text('Zone: ${data['zone'] ?? '-'}'),
                              Text(
                                'Credibility: ${data['credibility_score'] ?? 0}',
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  children: <Widget>[
                    _statCard('Assigned', assigned),
                    _statCard('Completed', completed),
                    _statCard('Under Review', underReview),
                    _statCard('SLA Warn', slaWarnings),
                  ],
                ),
              ],
            );
          },
    );
  }

  Widget _statCard(String title, int count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(title),
            Text(
              '$count',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(ReportModel report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            if (report.imageUrl.isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.network(
                  report.imageUrl,
                  height: 140,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              report.category,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            Text(report.description),
            Text('Location: ${report.latitude}, ${report.longitude}'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                Chip(
                  label: Text(
                    report.priority.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: colorForPriority(report.priority),
                ),
                Chip(label: Text(report.status)),
                Chip(
                  label: Text(
                    report.slaBreachFlag ? 'SLA Breached' : _slaLabel(report),
                  ),
                  backgroundColor: report.slaBreachFlag
                      ? Colors.red.shade100
                      : Colors.green.shade100,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                FilledButton.tonalIcon(
                  onPressed: () => _openMaps(report.latitude, report.longitude),
                  icon: const Icon(Icons.navigation_outlined),
                  label: const Text('Navigate to Issue'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _startWorkAttendance(report.id),
                  icon: const Icon(Icons.play_circle_outline),
                  label: const Text('Start Work'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _uploadRepair(report.id),
                  icon: const Icon(Icons.upload_file_outlined),
                  label: const Text('Upload Repair Proof'),
                ),
                FilledButton.tonalIcon(
                  onPressed: () => _updateStatus(report.id, report.status),
                  icon: const Icon(Icons.sync_alt_outlined),
                  label: const Text('Update Task Status'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _uploadRepair(String reportId) async {
    try {
      final XFile? image = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (image == null) {
        return;
      }
      await _repository.uploadRepairImage(
        reportId: reportId,
        imageFile: File(image.path),
        workerId: widget.worker.uid,
      );
      if (!mounted) {
        return;
      }
      await HapticService.mediumAction();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Repair proof uploaded. Task moved to Under Review for admin verification.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload repair image')),
      );
    }
  }

  Future<void> _updateStatus(String reportId, String current) async {
    final String? selected = await showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return SimpleDialog(
          title: const Text('Update Task Status'),
          children: <Widget>[
            for (final String status in const <String>[
              'Assigned',
              'In Progress',
            ])
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, status),
                child: Text(status),
              ),
          ],
        );
      },
    );

    if (selected != null && selected != current) {
      try {
        await HapticService.mediumAction();
        await _repository.updateStatus(
          reportId,
          selected,
          actorId: widget.worker.uid,
          actorRole: 'worker',
        );
        if (selected == 'In Progress') {
          unawaited(_analytics.logWorkerTaskStarted(taskId: reportId));
        }
      } catch (_) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update status.')),
        );
      }
    }
  }

  Future<void> _startWorkAttendance(String reportId) async {
    try {
      final XFile? selfie = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: 75,
      );
      if (selfie == null) {
        return;
      }
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Enable GPS to mark attendance')),
        );
        return;
      }
      LocationPermission p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }
      if (p == LocationPermission.denied ||
          p == LocationPermission.deniedForever) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Location permission denied')),
        );
        return;
      }

      final Position pos = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      await _repository.markWorkerAttendance(
        reportId: reportId,
        workerId: widget.worker.uid,
        selfieImage: File(selfie.path),
        latitude: pos.latitude,
        longitude: pos.longitude,
      );
      unawaited(_analytics.logWorkerAttendanceMarked(taskId: reportId));
      if (!mounted) {
        return;
      }
      await HapticService.success();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance marked on-site')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark attendance right now')),
      );
    }
  }

  String _slaLabel(ReportModel report) {
    if (report.assignedAt == null || report.status == 'Fixed') {
      return 'SLA On Track';
    }
    final Duration limit = switch (report.priority.toLowerCase()) {
      'high' || 'critical' => const Duration(hours: 6),
      'medium' => const Duration(hours: 24),
      _ => const Duration(hours: 48),
    };
    final DateTime due = report.assignedAt!.add(limit);
    final Duration left = due.difference(DateTime.now());
    if (left.isNegative) {
      return 'SLA Due';
    }
    return 'SLA ${left.inHours}h left';
  }

  bool _isNearSlaBreach(ReportModel report) {
    if (report.assignedAt == null) {
      return false;
    }
    final Duration limit = switch (report.priority.toLowerCase()) {
      'high' || 'critical' => const Duration(hours: 6),
      'medium' => const Duration(hours: 24),
      _ => const Duration(hours: 48),
    };
    final DateTime due = report.assignedAt!.add(limit);
    final Duration left = due.difference(DateTime.now());
    return !left.isNegative && left.inHours <= 2;
  }

  Future<void> _openMaps(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

  Widget _profile() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: widget.firestore
          .collection('workers')
          .doc(widget.worker.uid)
          .get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          'Name: ${data['name'] ?? widget.worker.name ?? '-'}',
                        ),
                        Text(
                          'Worker ID: ${data['worker_id'] ?? widget.worker.uid}',
                        ),
                        Text(
                          'Phone: ${data['phone'] ?? widget.worker.phone ?? '-'}',
                        ),
                        Text(
                          'Tasks Completed: ${data['completed_tasks'] ?? 0}',
                        ),
                        Text('Assigned Tasks: ${data['assigned_tasks'] ?? 0}'),
                        Text(
                          'Credibility Score: ${data['credibility_score'] ?? 0}',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
    );
  }
}
