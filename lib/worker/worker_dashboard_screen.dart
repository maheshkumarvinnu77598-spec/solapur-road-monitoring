import 'dart:async';
import 'dart:io';
<<<<<<< HEAD
=======
import 'dart:math';
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
<<<<<<< HEAD
import 'package:url_launcher/url_launcher.dart';

=======
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../authentication/auth_service.dart';
import '../authentication/screens/login_screen.dart';
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
import '../models/app_user.dart';
import '../models/report_model.dart';
import '../reporting/report_config.dart';
import '../reporting/report_repository.dart';
<<<<<<< HEAD
import '../services/analytics_service.dart';
import '../services/haptic_service.dart';
=======
import '../services/haptic_service.dart';
import '../services/supabase_service.dart';
import '../utils/priority_utils.dart';
import '../utils/resilient_ui.dart';
import 'assigned_reports_screen.dart';
import 'report_detail_screen.dart';
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

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
<<<<<<< HEAD
  final AnalyticsService _analytics = AnalyticsService.instance;
=======
  late final Stream<QuerySnapshot<Map<String, dynamic>>> _reportsStream;
  late final Future<DocumentSnapshot<Map<String, dynamic>>> _workerDocFuture;
  Position? _workerPosition;
  bool _attendanceMarkedToday = false;
  bool _isLoading = false;
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

  @override
  void initState() {
    super.initState();
    _repository = ReportRepository(firestore: widget.firestore);
<<<<<<< HEAD
=======
    _reportsStream = widget.firestore.collection('reports').snapshots();
    _workerDocFuture = widget.firestore
        .collection('workers')
        .doc(widget.worker.uid)
        .get();
    unawaited(_loadWorkerPosition());
    unawaited(_checkAttendanceStatus());
  }

  Future<void> _loadWorkerPosition() async {
    try {
      final bool enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        return;
      }
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        return;
      }
      final Position position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );
      if (mounted) {
        setState(() => _workerPosition = position);
      }
    } catch (_) {}
  }

  Future<void> _checkAttendanceStatus() async {
    try {
      final bool marked = await _hasAttendanceForToday(widget.worker.uid);
      if (mounted) {
        setState(() => _attendanceMarkedToday = marked);
      }
    } catch (_) {}
  }

  Future<bool> _hasAttendanceForToday(String workerId) async {
    final DateTime now = DateTime.now();
    final DateTime startOfDay = DateTime(now.year, now.month, now.day);
    final DateTime endOfDay = startOfDay.add(const Duration(days: 1));

    final QuerySnapshot<Map<String, dynamic>> snapshot = await widget.firestore
        .collection('attendance')
        .where('worker_id', isEqualTo: workerId)
        .where(
          'timestamp',
          isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay),
        )
        .where('timestamp', isLessThan: Timestamp.fromDate(endOfDay))
        .limit(1)
        .get();

    return snapshot.docs.isNotEmpty;
  }

  Future<void> markAttendance() async {
    if (_isLoading) {
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String workerId = widget.worker.uid;
      final bool alreadyMarked = await _hasAttendanceForToday(workerId);
      if (alreadyMarked) {
        if (!mounted) {
          return;
        }
        setState(() => _attendanceMarkedToday = true);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Already marked today')));
        return;
      }

      final ImagePicker picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: ImageSource.camera);

      if (picked == null) {
        return;
      }

      final File file = File(picked.path);

      final String? imageUrl = await SupabaseService().uploadAttendanceImage(
        file: file,
        workerId: workerId,
      );

      if (imageUrl == null) {
        if (!mounted) {
          return;
        }
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Image upload failed')));
        return;
      }

      Position? position;

      try {
        position = await Geolocator.getCurrentPosition();
        if (mounted) {
          setState(() => _workerPosition = position);
        }
      } catch (_) {}

      await FirebaseFirestore.instance
          .collection('attendance')
          .add(<String, dynamic>{
            'worker_id': workerId,
            'image_url': imageUrl,
            'lat': position?.latitude,
            'lng': position?.longitude,
            'timestamp': FieldValue.serverTimestamp(),
            'status': 'present',
          });

      if (!mounted) {
        return;
      }
      setState(() => _attendanceMarkedToday = true);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance marked')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Attendance failed')));
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _logoutWorker() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.remove('worker_session');
    await prefs.remove('worker_session_worker_id');
    if (!mounted) {
      return;
    }
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(authService: AuthService()),
      ),
      (Route<dynamic> route) => false,
    );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
        onDestinationSelected: (int i) => setState(() => _index = i),
=======
        onDestinationSelected: (int value) => setState(() => _index = value),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
      stream: widget.firestore
          .collection('reports')
          .where('assigned_worker', isEqualTo: widget.worker.uid)
          .snapshots(),
=======
      stream: _reportsStream,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (snapshot.hasError) {
              return const Center(
<<<<<<< HEAD
                child: Text(
                  'Unable to load tasks right now. Check your network and try again.',
                ),
=======
                child: Text('Unable to load tasks right now.'),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<ReportModel> reports = snapshot.data!.docs
                .map(ReportModel.fromDoc)
                .where(
<<<<<<< HEAD
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
=======
                  (ReportModel report) => completed
                      ? report.assignedWorker == widget.worker.uid &&
                            report.status == 'Fixed'
                      : report.assignedWorker == widget.worker.uid &&
                            (report.status == 'Assigned' ||
                                report.status == 'In Progress' ||
                                report.status == 'Under Review'),
                )
                .toList(growable: true);

            final Position? workerPosition = _workerPosition;
            reports.sort((a, b) {
              final int aRank = priorityRank[a.priority.toLowerCase()] ?? 0;
              final int bRank = priorityRank[b.priority.toLowerCase()] ?? 0;
              if (aRank != bRank) {
                return bRank.compareTo(aRank);
              }
              if (workerPosition == null) {
                return 0;
              }
              final double aDistance = _haversineKm(
                workerPosition.latitude,
                workerPosition.longitude,
                a.latitude,
                a.longitude,
              );
              final double bDistance = _haversineKm(
                workerPosition.latitude,
                workerPosition.longitude,
                b.latitude,
                b.longitude,
              );
              return aDistance.compareTo(bDistance);
            });

            final int assignedCount = reports
                .where((ReportModel report) => report.status == 'Assigned')
                .length;
            final int underReviewCount = reports
                .where((ReportModel report) => report.status == 'Under Review')
                .length;
            final int completeCount = reports
                .where((ReportModel report) => report.status == 'Fixed')
                .length;
            final int slaWarnings = reports
                .where(
                  (ReportModel report) =>
                      !completed && _isNearSlaBreach(report),
                )
                .length;

            return ListView(
              padding: const EdgeInsets.all(16),
              children: <Widget>[
                if (!completed) ...<Widget>[
                  _overviewSection(
                    assigned: assignedCount,
                    completed: completeCount,
                    underReview: underReviewCount,
                    slaWarnings: slaWarnings,
                  ),
                  const SizedBox(height: 16),
                ],
                if (reports.isEmpty)
                  _emptyState(
                    completed
                        ? 'No completed tasks.'
                        : 'No assigned tasks available.',
                  )
                else
                  ...reports.map(_taskCard),
              ],
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
            );
          },
    );
  }

<<<<<<< HEAD
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
=======
  Widget _overviewSection({
    required int assigned,
    required int completed,
    required int underReview,
    required int slaWarnings,
  }) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;

    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _workerDocFuture,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
<<<<<<< HEAD
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
=======
            final String workerName =
                data['name'] as String? ?? widget.worker.name ?? 'Worker';
            final String workerId =
                data['worker_id'] as String? ?? widget.worker.uid;
            final String zone = data['zone'] as String? ?? '-';
            final String status = _attendanceMarkedToday
                ? 'Present'
                : 'Pending';

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Worker Overview',
                  style: textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 12),
                Card(
                  elevation: 3,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          workerName,
                          style: textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 12),
                        _detailRow('Worker ID', workerId),
                        const SizedBox(height: 10),
                        _detailRow('Zone', zone),
                        const SizedBox(height: 10),
                        _detailRow('Status', status),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: <Widget>[
                            FilledButton.icon(
                              onPressed: _isLoading ? null : markAttendance,
                              icon: _isLoading
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.camera_alt_outlined),
                              label: const Text('Mark Attendance'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (BuildContext context) =>
                                      AssignedReportsScreen(
                                        workerId: widget.worker.uid,
                                        firestore: widget.firestore,
                                      ),
                                ),
                              ),
                              icon: const Icon(Icons.view_list_outlined),
                              label: const Text('View Assigned Reports'),
                            ),
                          ],
                        ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
                      ],
                    ),
                  ),
                ),
<<<<<<< HEAD
                const SizedBox(height: 4),
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.6,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
=======
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
                  children: <Widget>[
                    _statCard('Assigned', assigned),
                    _statCard('Completed', completed),
                    _statCard('Under Review', underReview),
                    _statCard('SLA Warn', slaWarnings),
                  ],
                ),
<<<<<<< HEAD
=======
                if (_attendanceMarkedToday) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    'Attendance marked for today',
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.primary,
                    ),
                  ),
                ],
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
              ],
            );
          },
    );
  }

<<<<<<< HEAD
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
=======
  Widget _detailRow(String label, String value) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: <Widget>[
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }

  Widget _statCard(String title, int count) {
    final TextTheme textTheme = Theme.of(context).textTheme;
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Text(
              title,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              '$count',
              style: textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskCard(ReportModel report) {
<<<<<<< HEAD
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
=======
    final ColorScheme colorScheme = Theme.of(context).colorScheme;
    final TextTheme textTheme = Theme.of(context).textTheme;
    final Color priorityColor = colorForPriority(report.priority);
    final Position? workerPosition = _workerPosition;
    final double? distanceKm = workerPosition == null
        ? null
        : _haversineKm(
            workerPosition.latitude,
            workerPosition.longitude,
            report.latitude,
            report.longitude,
          );

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _openReportDetails(report),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (report.imageUrl.isNotEmpty) ...<Widget>[
                DemoNetworkImage(
                  imageUrl: report.imageUrl,
                  height: 160,
                  borderRadius: BorderRadius.circular(12),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                report.category,
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                report.description,
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 160,
                child: DemoMapPreview(
                  latitude: report.latitude,
                  longitude: report.longitude,
                  height: 160,
                  zoom: 16,
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Location: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                style: textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: <Widget>[
                  Chip(
                    backgroundColor: priorityColor,
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
                  ),
                  Chip(label: Text(report.status)),
                  if (distanceKm != null)
                    Chip(
                      label: Text('${distanceKm.toStringAsFixed(1)} km away'),
                    ),
                  Chip(
                    label: Text(
                      report.slaBreachFlag ? 'SLA Breached' : _slaLabel(report),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        _openMaps(report.latitude, report.longitude),
                    icon: const Icon(Icons.navigation_outlined),
                    label: const Text('Navigate'),
                  ),
                  if (report.status == 'Assigned')
                    FilledButton.tonalIcon(
                      onPressed: () => _startRepair(report.id),
                      icon: const Icon(Icons.play_circle_outline),
                      label: const Text('Start Repair'),
                    ),
                  if (report.status == 'In Progress') ...<Widget>[
                    FilledButton.tonalIcon(
                      onPressed: () => _uploadRepair(report.id),
                      icon: const Icon(Icons.upload_file_outlined),
                      label: const Text('Upload Proof'),
                    ),
                    FilledButton.tonalIcon(
                      onPressed: () => _markCompleted(report.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark Completed'),
                    ),
                  ],
                  if (report.status == 'Under Review')
                    FilledButton.tonalIcon(
                      onPressed: () => _markCompleted(report.id),
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Mark Completed'),
                    ),
                ],
              ),
            ],
          ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        ),
      ),
    );
  }

<<<<<<< HEAD
=======
  Widget _emptyState(String text) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Center(child: Text(text)),
      ),
    );
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Repair proof uploaded. Task moved to Under Review for admin verification.',
          ),
        ),
      );
=======
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Repair proof uploaded.')));
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to upload repair image')),
      );
    }
  }

<<<<<<< HEAD
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
=======
  Future<void> _startRepair(String reportId) async {
    try {
      await HapticService.mediumAction();
      await _repository.updateStatus(
        reportId,
        'In Progress',
        actorId: widget.worker.uid,
        actorRole: 'worker',
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Repair started')));
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    } catch (_) {
      if (!mounted) {
        return;
      }
<<<<<<< HEAD
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Unable to mark attendance right now')),
      );
=======
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to start repair')));
    }
  }

  Future<void> _markCompleted(String reportId) async {
    try {
      await HapticService.mediumAction();
      await _repository.completeRepair(
        reportId: reportId,
        workerId: widget.worker.uid,
      );
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Task marked as completed')));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Failed to mark completed')));
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    }
  }

  String _slaLabel(ReportModel report) {
    if (report.assignedAt == null || report.status == 'Fixed') {
      return 'SLA On Track';
    }
<<<<<<< HEAD
    final Duration limit = switch (report.priority.toLowerCase()) {
      'high' || 'critical' => const Duration(hours: 6),
      'medium' => const Duration(hours: 24),
      _ => const Duration(hours: 48),
    };
=======
    final Duration limit = slaForReport(
      category: report.category,
      priority: report.priority,
    );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    final DateTime due = report.assignedAt!.add(limit);
    final Duration left = due.difference(DateTime.now());
    if (left.isNegative) {
      return 'SLA Due';
    }
<<<<<<< HEAD
=======
    if (left.inHours == 0) {
      return 'SLA ${left.inMinutes}m left';
    }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    return 'SLA ${left.inHours}h left';
  }

  bool _isNearSlaBreach(ReportModel report) {
    if (report.assignedAt == null) {
      return false;
    }
<<<<<<< HEAD
    final Duration limit = switch (report.priority.toLowerCase()) {
      'high' || 'critical' => const Duration(hours: 6),
      'medium' => const Duration(hours: 24),
      _ => const Duration(hours: 48),
    };
=======
    final Duration limit = slaForReport(
      category: report.category,
      priority: report.priority,
    );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    final DateTime due = report.assignedAt!.add(limit);
    final Duration left = due.difference(DateTime.now());
    return !left.isNegative && left.inHours <= 2;
  }

<<<<<<< HEAD
  Future<void> _openMaps(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (!mounted) {
        return;
      }
=======
  double _haversineKm(
    double startLat,
    double startLng,
    double endLat,
    double endLng,
  ) {
    const double earthRadiusKm = 6371;
    final double dLat = _degreesToRadians(endLat - startLat);
    final double dLng = _degreesToRadians(endLng - startLng);
    final double a =
        (sin(dLat / 2) * sin(dLat / 2)) +
        cos(_degreesToRadians(startLat)) *
            cos(_degreesToRadians(endLat)) *
            (sin(dLng / 2) * sin(dLng / 2));
    final double c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return earthRadiusKm * c;
  }

  double _degreesToRadians(double degrees) => degrees * (pi / 180);

  Future<void> _openMaps(double lat, double lng) async {
    final Uri uri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1&destination=$lat,$lng',
    );
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not open maps.')));
    }
  }

<<<<<<< HEAD
  Widget _profile() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: widget.firestore
          .collection('workers')
          .doc(widget.worker.uid)
          .get(),
=======
  void _openReportDetails(ReportModel report) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => ReportDetailScreen(
          reportId: report.id,
          workerId: widget.worker.uid,
          firestore: widget.firestore,
        ),
      ),
    );
  }

  Widget _profile() {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _workerDocFuture,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      builder:
          (
            BuildContext context,
            AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final Map<String, dynamic> data =
                snapshot.data?.data() ?? <String, dynamic>{};
<<<<<<< HEAD
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
=======
            return SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Card(
                elevation: 3,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Profile',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _detailRow(
                        'Name',
                        data['name'] as String? ?? widget.worker.name ?? '-',
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        'Worker ID',
                        data['worker_id'] as String? ?? widget.worker.uid,
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        'Phone',
                        data['phone'] as String? ?? widget.worker.phone ?? '-',
                      ),
                      const SizedBox(height: 10),
                      _detailRow(
                        'Completed',
                        '${data['completed_tasks'] ?? 0}',
                      ),
                      const SizedBox(height: 10),
                      _detailRow('Assigned', '${data['assigned_tasks'] ?? 0}'),
                      const SizedBox(height: 10),
                      _detailRow(
                        'Credibility',
                        '${data['credibility_score'] ?? 0}',
                      ),
                      const SizedBox(height: 16),
                      FilledButton.tonalIcon(
                        onPressed: _logoutWorker,
                        icon: const Icon(Icons.logout),
                        label: const Text('Logout'),
                      ),
                    ],
                  ),
                ),
              ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
            );
          },
    );
  }
}
