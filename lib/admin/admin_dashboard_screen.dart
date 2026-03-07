import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/report_model.dart';
import '../reporting/report_config.dart';
import '../reporting/report_repository.dart';
import '../services/csv_export_service.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({
    super.key,
    required this.repository,
    required this.onLogout,
  });

  final ReportRepository repository;
  final Future<void> Function() onLogout;

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _tab = 0;

  final TextEditingController _workerNameCtrl = TextEditingController();
  final TextEditingController _workerPhoneCtrl = TextEditingController();
  final TextEditingController _workerZoneCtrl = TextEditingController();
  final TextEditingController _workerPasswordCtrl = TextEditingController();

  XFile? _workerPhoto;
  bool _creatingWorker = false;

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseFunctions _functions = FirebaseFunctions.instance;
  final CsvExportService _csvExportService = CsvExportService();

  @override
  void dispose() {
    _workerNameCtrl.dispose();
    _workerPhoneCtrl.dispose();
    _workerZoneCtrl.dispose();
    _workerPasswordCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        actions: [
          IconButton(
            onPressed: widget.onLogout,
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment<int>(value: 0, label: Text('Reports')),
                ButtonSegment<int>(value: 1, label: Text('Create Worker')),
                ButtonSegment<int>(value: 2, label: Text('Workers')),
                ButtonSegment<int>(value: 3, label: Text('Settings')),
              ],
              selected: <int>{_tab},
              onSelectionChanged: (Set<int> s) =>
                  setState(() => _tab = s.first),
            ),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _tab == 0
                  ? _reportsView()
                  : _tab == 1
                  ? _createWorkerView()
                  : _tab == 2
                  ? _workersView()
                  : _settingsView(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportsView() {
    return StreamBuilder<List<ReportModel>>(
      stream: widget.repository.allReports(),
      builder:
          (BuildContext context, AsyncSnapshot<List<ReportModel>> snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final List<ReportModel> reports = snapshot.data!;
            final int pending = reports
                .where((ReportModel r) => r.status == 'Reported')
                .length;
            final int inProgress = reports
                .where((ReportModel r) => r.status == 'In Progress')
                .length;
            final int resolved = reports
                .where((ReportModel r) => r.status == 'Resolved')
                .length;

            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: 1.8,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  children: [
                    _overview('Total Reports', reports.length),
                    _overview('Pending Reports', pending),
                    _overview('Resolved Reports', resolved),
                    FutureBuilder<double>(
                      future: _avgCredibility(),
                      builder: (BuildContext context, AsyncSnapshot<double> s) {
                        return _overview(
                          'Worker Credibility',
                          s.hasData ? s.data!.toStringAsFixed(1) : '... ',
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _analyticsSection(reports),
                _exportActions(),
                const SizedBox(height: 8),
                ...reports.map(_reportCard),
                if (reports.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: Text('No reports found.')),
                  ),
                if (inProgress > 0) const SizedBox(height: 4),
              ],
            );
          },
    );
  }

  Widget _analyticsSection(List<ReportModel> reports) {
    final Map<String, int> byCategory = <String, int>{};
    final Map<String, int> byArea = <String, int>{};
    for (final r in reports) {
      byCategory[r.category] = (byCategory[r.category] ?? 0) + 1;
      final String areaKey =
          '${r.latitude.toStringAsFixed(2)}, ${r.longitude.toStringAsFixed(2)}';
      byArea[areaKey] = (byArea[areaKey] ?? 0) + 1;
    }

    return Column(
      children: [
        _weeklyAnalyticsCard(reports),
        _barChartCard('Top Issue Types', byCategory),
        _slaCard(reports),
        _workerPerformanceCard(),
        _workerLeaderboardCard(),
        _barChartCard('Issues by Area', byArea),
      ],
    );
  }

  Widget _weeklyAnalyticsCard(List<ReportModel> reports) {
    final DateTime since = DateTime.now().subtract(const Duration(days: 7));
    final List<ReportModel> weekly = reports
        .where((r) => r.timestamp.isAfter(since))
        .toList(growable: false);
    final int resolved = weekly.where((r) => r.status == 'Resolved').length;
    final int withTimes = weekly
        .where((r) => r.assignedAt != null && r.resolvedAt != null)
        .length;
    final double avgHours = withTimes == 0
        ? 0
        : weekly
                  .where((r) => r.assignedAt != null && r.resolvedAt != null)
                  .fold<int>(
                    0,
                    (totalMins, r) =>
                        totalMins +
                        r.resolvedAt!.difference(r.assignedAt!).inMinutes,
                  ) /
              withTimes /
              60.0;
    return Card(
      child: ListTile(
        title: const Text('Weekly Analytics'),
        subtitle: Text(
          'Reports: ${weekly.length}\nResolved: $resolved\nAvg resolution: ${avgHours.toStringAsFixed(1)}h',
        ),
      ),
    );
  }

  Widget _slaCard(List<ReportModel> reports) {
    final resolved = reports.where((r) => r.resolvedAt != null).toList();
    final breached = reports.where((r) => r.slaBreachFlag).length;

    double avgHours = 0;
    if (resolved.isNotEmpty) {
      final totalMinutes = resolved.fold<int>(0, (prev, r) {
        if (r.assignedAt == null || r.resolvedAt == null) {
          return prev;
        }
        return prev + r.resolvedAt!.difference(r.assignedAt!).inMinutes;
      });
      avgHours = totalMinutes / resolved.length / 60.0;
    }

    final int totalTracked = reports.where((r) => r.assignedAt != null).length;
    final double compliance = totalTracked == 0
        ? 100
        : ((totalTracked - breached) / totalTracked) * 100;

    return Card(
      child: ListTile(
        title: const Text('SLA Tracking'),
        subtitle: Text(
          'Avg Resolution: ${avgHours.toStringAsFixed(1)} h\n'
          'Compliance: ${compliance.toStringAsFixed(1)}%\n'
          'Breached Tasks: $breached',
        ),
      ),
    );
  }

  Widget _exportActions() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.tonalIcon(
              onPressed: _exportReports,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export Reports CSV'),
            ),
            FilledButton.tonalIcon(
              onPressed: _exportWorkers,
              icon: const Icon(Icons.file_download_outlined),
              label: const Text('Export Worker Performance CSV'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _barChartCard(String title, Map<String, int> values) {
    final entries = values.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = entries.take(4).toList();
    final int maxVal = top.isEmpty ? 1 : top.first.value;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (top.isEmpty) const Text('No data available'),
            for (final e in top) ...[
              Text(e.key, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: e.value / maxVal),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }

  Widget _workerPerformanceCard() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('workers').get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final docs = snapshot.data?.docs ?? const [];
            final Map<String, int> performance = {
              for (final d in docs)
                (d.data()['worker_id'] as String? ?? d.id):
                    (d.data()['completed_tasks'] as num?)?.toInt() ?? 0,
            };
            return _barChartCard('Worker Performance', performance);
          },
    );
  }

  Widget _workerLeaderboardCard() {
    return FutureBuilder<QuerySnapshot<Map<String, dynamic>>>(
      future: _firestore.collection('workers').get(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            final docs = snapshot.data?.docs ?? const [];
            docs.sort((a, b) {
              final aData = a.data();
              final bData = b.data();
              final double aScore =
                  ((aData['completed_tasks'] as num?)?.toDouble() ?? 0) * 0.5 +
                  ((aData['credibility_score'] as num?)?.toDouble() ?? 0) * 0.5;
              final double bScore =
                  ((bData['completed_tasks'] as num?)?.toDouble() ?? 0) * 0.5 +
                  ((bData['credibility_score'] as num?)?.toDouble() ?? 0) * 0.5;
              return bScore.compareTo(aScore);
            });

            final top = docs.take(5).toList(growable: false);
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Worker Leaderboard',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    if (top.isEmpty) const Text('No workers yet'),
                    for (int i = 0; i < top.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 6),
                        child: Text(
                          '${i + 1}. ${top[i].data()['name'] ?? '-'} (${top[i].data()['worker_id'] ?? top[i].id})',
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
    );
  }

  Widget _overview(String title, Object count) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(title),
            const SizedBox(height: 4),
            Text(
              '$count',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }

  Widget _reportCard(ReportModel report) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              report.category,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            Text(report.description),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  label: Text(
                    report.priority.toUpperCase(),
                    style: const TextStyle(color: Colors.white),
                  ),
                  backgroundColor: colorForPriority(report.priority),
                ),
                DropdownButton<String>(
                  value: reportStatuses.contains(report.status)
                      ? report.status
                      : reportStatuses.first,
                  items: reportStatuses
                      .map(
                        (String s) =>
                            DropdownMenuItem<String>(value: s, child: Text(s)),
                      )
                      .toList(growable: false),
                  onChanged: (String? value) async {
                    if (value != null) {
                      try {
                        await widget.repository.updateStatus(
                          report.id,
                          value,
                          actorId:
                              FirebaseAuth.instance.currentUser?.uid ?? 'admin',
                          actorRole: 'admin',
                        );
                      } catch (_) {
                        _show('Failed to update report status.', isError: true);
                      }
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: () => _assignWorkerDialog(report.id),
                    child: const Text('Assign Worker'),
                  ),
                ),
              ],
            ),
            if (report.repairImage != null &&
                report.repairImage!.isNotEmpty) ...[
              const SizedBox(height: 8),
              const Text('Repair Image (Verification):'),
              const SizedBox(height: 4),
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  report.repairImage!,
                  height: 120,
                  fit: BoxFit.cover,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _assignWorkerDialog(String reportId) async {
    final TextEditingController ctrl = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Assign Worker'),
          content: TextField(
            controller: ctrl,
            decoration: const InputDecoration(labelText: 'Worker Document ID'),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                final String workerId = ctrl.text.trim();
                if (workerId.isNotEmpty) {
                  try {
                    await widget.repository.assignWorker(
                      reportId: reportId,
                      workerId: workerId,
                      actorId:
                          FirebaseAuth.instance.currentUser?.uid ?? 'admin',
                      actorRole: 'admin',
                    );
                  } catch (_) {
                    _show('Failed to assign worker.', isError: true);
                  }
                }
                if (context.mounted) {
                  Navigator.pop(context);
                }
              },
              child: const Text('Assign'),
            ),
          ],
        );
      },
    );
    ctrl.dispose();
  }

  Widget _createWorkerView() {
    return ListView(
      key: const ValueKey<String>('create-worker'),
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                GestureDetector(
                  onTap: _pickWorkerPhoto,
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _workerPhoto == null
                        ? null
                        : FileImage(File(_workerPhoto!.path)),
                    child: _workerPhoto == null
                        ? const Icon(Icons.add_a_photo_outlined)
                        : null,
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _workerNameCtrl,
                  decoration: const InputDecoration(labelText: 'Worker name'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _workerPhoneCtrl,
                  decoration: const InputDecoration(labelText: 'Phone number'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _workerZoneCtrl,
                  decoration: const InputDecoration(labelText: 'Assigned zone'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _workerPasswordCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: _creatingWorker ? null : _createWorker,
                  icon: const Icon(Icons.person_add_alt_1),
                  label: _creatingWorker
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Create Worker (Auto ID)'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _workersView() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      key: const ValueKey<String>('workers-list'),
      stream: _firestore.collection('workers').orderBy('worker_id').snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
          ) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final docs = snapshot.data!.docs;
            if (docs.isEmpty) {
              return const Center(child: Text('No workers created yet.'));
            }

            return ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: docs.length,
              itemBuilder: (BuildContext context, int index) {
                final data = docs[index].data();
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          (data['photo_url'] as String? ?? '').isNotEmpty
                          ? NetworkImage(data['photo_url'] as String)
                          : null,
                      child: (data['photo_url'] as String? ?? '').isEmpty
                          ? const Icon(Icons.person_outline)
                          : null,
                    ),
                    title: Text(
                      '${data['name'] ?? '-'} (${data['worker_id'] ?? '-'})',
                    ),
                    subtitle: Text(
                      'Zone: ${data['zone'] ?? '-'}\nCredibility: ${data['credibility_score'] ?? 0}',
                    ),
                    isThreeLine: true,
                  ),
                );
              },
            );
          },
    );
  }

  Future<void> _pickWorkerPhoto() async {
    final XFile? picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
    );
    if (picked != null) {
      setState(() => _workerPhoto = picked);
    }
  }

  Future<void> _createWorker() async {
    final String name = _workerNameCtrl.text.trim();
    final String phone = _workerPhoneCtrl.text.trim();
    final String zone = _workerZoneCtrl.text.trim();
    final String password = _workerPasswordCtrl.text.trim();

    if (name.isEmpty || phone.isEmpty || zone.isEmpty || password.isEmpty) {
      _show('Fill all worker fields.', isError: true);
      return;
    }

    setState(() => _creatingWorker = true);

    try {
      String photoUrl = '';

      if (_workerPhoto != null) {
        final String tempWorkerId =
            'pending-${DateTime.now().millisecondsSinceEpoch}';
        final String path =
            'workers/$tempWorkerId/${DateTime.now().millisecondsSinceEpoch}.jpg';
        final snap = await _storage.ref(path).putFile(File(_workerPhoto!.path));
        photoUrl = await snap.ref.getDownloadURL();
      }

      final HttpsCallable callable = _functions.httpsCallable(
        'createWorkerAccount',
      );
      final HttpsCallableResult<dynamic> result = await callable
          .call(<String, dynamic>{
            'name': name,
            'phone': phone,
            'zone': zone,
            'password': password,
            'photo_url': photoUrl,
          });
      final Map<String, dynamic> payload = Map<String, dynamic>.from(
        result.data as Map,
      );
      final String workerId = payload['worker_id'] as String? ?? '';
      if (workerId.isEmpty) {
        throw StateError('Missing worker ID from backend.');
      }

      _show('Worker created: $workerId');
      _workerNameCtrl.clear();
      _workerPhoneCtrl.clear();
      _workerZoneCtrl.clear();
      _workerPasswordCtrl.clear();
      setState(() => _workerPhoto = null);
    } on FirebaseFunctionsException catch (e) {
      _show(e.message ?? 'Failed to create worker.', isError: true);
    } catch (_) {
      _show('Failed to create worker.', isError: true);
    } finally {
      if (mounted) {
        setState(() => _creatingWorker = false);
      }
    }
  }

  Future<double> _avgCredibility() async {
    final QuerySnapshot<Map<String, dynamic>> snap = await _firestore
        .collection('workers')
        .get();
    if (snap.docs.isEmpty) {
      return 0;
    }
    double sum = 0;
    for (final d in snap.docs) {
      sum += (d.data()['credibility_score'] as num?)?.toDouble() ?? 0;
    }
    return sum / snap.docs.length;
  }

  void _show(String msg, {bool isError = false}) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: isError ? Colors.red : null,
        ),
      );
  }

  Future<void> _exportReports() async {
    try {
      final file = await _csvExportService.exportReportsCsv();
      _show('Reports exported: ${file.path}');
    } catch (_) {
      _show('Failed to export reports CSV', isError: true);
    }
  }

  Future<void> _exportWorkers() async {
    try {
      final file = await _csvExportService.exportWorkersCsv();
      _show('Worker export: ${file.path}');
    } catch (_) {
      _show('Failed to export workers CSV', isError: true);
    }
  }

  Widget _settingsView() {
    return ListView(
      key: const ValueKey<String>('admin-settings'),
      padding: const EdgeInsets.all(16),
      children: const [
        Card(
          child: ListTile(
            title: Text('Worker Account Management'),
            subtitle: Text(
              'Use Create Worker tab to create/update worker credentials.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Assignment Rules'),
            subtitle: Text(
              'Zone-based auto assignment and manual reassignment are enabled.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Shift Timing'),
            subtitle: Text('Current worker shift window: 9:00 AM to 6:00 PM'),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('Notification Configuration'),
            subtitle: Text(
              'FCM push + in-app notifications enabled for report updates.',
            ),
          ),
        ),
        Card(
          child: ListTile(
            title: Text('System Logs'),
            subtitle: Text(
              'Audit events are tracked in reports/{reportId}/report_events.',
            ),
          ),
        ),
      ],
    );
  }
}
