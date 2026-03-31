<<<<<<< HEAD
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'firebase_options.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
=======
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'screens/dashboard_screen.dart';

const Color _primary = Color(0xFF77B6EA);
const Color _background = Color(0xFFE8EEF2);
const Color _card = Color(0xFFC7D3DD);
const Color _accent = Color(0xFFD6C9C9);
const Color _text = Color(0xFF37393A);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: const FirebaseOptions(
      apiKey: 'AIzaSyDh2QTNWyQ88piHmmVnLpRV5tPoWiEHJH4',
      appId: '1:94080701473:web:56a39eb44cc6568f177f60',
      messagingSenderId: '94080701473',
      projectId: 'solapur-road-monitoring',
      storageBucket: 'solapur-road-monitoring.firebasestorage.app',
    ),
  );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  runApp(const AdminDashboardApp());
}

class AdminDashboardApp extends StatelessWidget {
  const AdminDashboardApp({super.key});

  @override
  Widget build(BuildContext context) {
<<<<<<< HEAD
    const Color primary = Color(0xFF77B6EA);
    const Color background = Color(0xFFE8EEF2);
    const Color card = Color(0xFFC7D3DD);
    const Color accent = Color(0xFFD6C9C9);
    const Color text = Color(0xFF37393A);
=======
    final ColorScheme colorScheme = const ColorScheme.light().copyWith(
      primary: _primary,
      secondary: _accent,
      surface: _card,
      onSurface: _text,
    );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Solapur Admin Dashboard',
      theme: ThemeData(
<<<<<<< HEAD
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.light(
          primary: primary,
          secondary: accent,
          surface: card,
          onSurface: text,
          onPrimary: text,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: primary,
          foregroundColor: text,
          elevation: 0,
        ),
        cardTheme: const CardThemeData(
          color: card,
          elevation: 1,
          margin: EdgeInsets.zero,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: text),
          titleMedium: TextStyle(color: text),
        ),
      ),
      home: const AuthGate(),
    );
  }
}

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (BuildContext context, AsyncSnapshot<User?> snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const _LoadingPage();
        }
        final User? user = snapshot.data;
        if (user == null) {
          return const LoginPage();
        }

        return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          future: FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .get(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<DocumentSnapshot<Map<String, dynamic>>> roleSnap,
              ) {
                if (!roleSnap.hasData) {
                  return const _LoadingPage();
                }
                final String role =
                    (roleSnap.data?.data()?['role'] as String? ?? '')
                        .toLowerCase();
                if (role != 'admin') {
                  return const AccessDeniedPage();
                }
                return const DashboardPage();
              },
        );
      },
    );
  }
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailCtrl = TextEditingController();
  final TextEditingController _passwordCtrl = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      _show('Enter email and password.');
      return;
    }

    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
      );
    } on FirebaseAuthException catch (e) {
      _show(e.message ?? 'Login failed.');
    } catch (_) {
      _show('Unable to login right now.');
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  void _show(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Card(
            margin: const EdgeInsets.all(24),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  const Text(
                    'Admin Login',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _emailCtrl,
                    decoration: const InputDecoration(labelText: 'Email'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _passwordCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Password'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _login,
                    child: _loading
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Login'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AccessDeniedPage extends StatelessWidget {
  const AccessDeniedPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Access Denied')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const Text('This account is not an admin account.'),
            const SizedBox(height: 12),
            FilledButton.tonal(
              onPressed: () => FirebaseAuth.instance.signOut(),
              child: const Text('Sign Out'),
            ),
          ],
        ),
      ),
    );
  }
}

class DashboardPage extends StatefulWidget {
  const DashboardPage({super.key});

  @override
  State<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends State<DashboardPage> {
  int _index = 0;
  final AdminService _service = AdminService();

  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      OverviewTab(service: _service),
      ReportsTab(service: _service),
      WorkersTab(service: _service),
      MapTab(service: _service),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Solapur Road Monitoring Admin'),
        actions: <Widget>[
          IconButton(
            onPressed: () => FirebaseAuth.instance.signOut(),
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
          ),
        ],
      ),
      body: Row(
        children: <Widget>[
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (int i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: const <NavigationRailDestination>[
              NavigationRailDestination(
                icon: Icon(Icons.dashboard_outlined),
                label: Text('Overview'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.report_outlined),
                label: Text('Reports'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.people_outline),
                label: Text('Workers'),
              ),
              NavigationRailDestination(
                icon: Icon(Icons.map_outlined),
                label: Text('Map'),
              ),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: pages[_index],
            ),
          ),
        ],
      ),
    );
  }
}

class OverviewTab extends StatelessWidget {
  const OverviewTab({super.key, required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: service.reportsCollection.snapshots(),
      builder:
          (
            BuildContext context,
            AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> reportSnap,
          ) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: service.workersCollection.snapshots(),
              builder:
                  (
                    BuildContext context,
                    AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>>
                    workerSnap,
                  ) {
                    if (!reportSnap.hasData || !workerSnap.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    reports = reportSnap.data!.docs;
                    final List<QueryDocumentSnapshot<Map<String, dynamic>>>
                    workers = workerSnap.data!.docs;

                    final int totalReports = reports.length;
                    final int pendingRepairs = reports.where((doc) {
                      final String s =
                          (doc.data()['status'] as String? ?? 'Reported');
                      return s != 'Fixed';
                    }).length;
                    final int completedRepairs = reports.where((doc) {
                      return (doc.data()['status'] as String? ?? '') == 'Fixed';
                    }).length;
                    final int activeWorkers = workers.where((doc) {
                      final int pending =
                          (doc.data()['pending_tasks'] as num?)?.toInt() ?? 0;
                      return pending > 0;
                    }).length;

                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: <Widget>[
                        _MetricCard(
                          title: 'Total Reports',
                          value: '$totalReports',
                        ),
                        _MetricCard(
                          title: 'Pending Repairs',
                          value: '$pendingRepairs',
                        ),
                        _MetricCard(
                          title: 'Completed Repairs',
                          value: '$completedRepairs',
                        ),
                        _MetricCard(
                          title: 'Active Workers',
                          value: '$activeWorkers',
                        ),
                      ],
                    );
                  },
            );
          },
    );
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({required this.title, required this.value});

  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ReportsTab extends StatefulWidget {
  const ReportsTab({super.key, required this.service});

  final AdminService service;

  @override
  State<ReportsTab> createState() => _ReportsTabState();
}

class _ReportsTabState extends State<ReportsTab> {
  static const int _pageSize = 25;
  final List<ReportItem> _older = <ReportItem>[];
  DocumentSnapshot<Map<String, dynamic>>? _cursor;
  bool _loadingMore = false;

  Future<void> _loadMore(List<ReportItem> firstPage) async {
    if (_loadingMore) {
      return;
    }
    setState(() => _loadingMore = true);

    try {
      final List<ReportItem> next = await widget.service.fetchReportsPage(
        after: _cursor,
        limit: _pageSize,
      );
      if (next.isNotEmpty) {
        _cursor = next.last.rawDoc;
      }
      setState(() => _older.addAll(next));
    } catch (_) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not load more reports.')),
      );
    } finally {
      if (mounted) {
        setState(() => _loadingMore = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Expanded(
          child: StreamBuilder<List<ReportItem>>(
            stream: widget.service.reportsStream(limit: _pageSize),
            builder:
                (
                  BuildContext context,
                  AsyncSnapshot<List<ReportItem>> snapshot,
                ) {
                  if (snapshot.hasError) {
                    return const Center(child: Text('Failed to load reports.'));
                  }
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final List<ReportItem> latest = snapshot.data!;
                  if (_cursor == null && latest.isNotEmpty) {
                    _cursor = latest.last.rawDoc;
                  }

                  final Set<String> latestIds = latest.map((e) => e.id).toSet();
                  final List<ReportItem> combined = <ReportItem>[
                    ...latest,
                    ..._older.where((r) => !latestIds.contains(r.id)),
                  ];

                  return ListView.builder(
                    itemCount: combined.length,
                    itemBuilder: (BuildContext context, int index) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: ReportCard(
                          report: combined[index],
                          service: widget.service,
                        ),
                      );
                    },
                  );
                },
          ),
        ),
        const SizedBox(height: 10),
        FilledButton.tonal(
          onPressed: _loadingMore
              ? null
              : () => _loadMore(const <ReportItem>[]),
          child: _loadingMore
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Load More'),
        ),
      ],
    );
  }
}

class ReportCard extends StatefulWidget {
  const ReportCard({super.key, required this.report, required this.service});

  final ReportItem report;
  final AdminService service;

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } catch (e) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Action failed: $e')));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final ReportItem r = widget.report;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (r.imageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      r.imageUrl,
                      height: 90,
                      width: 120,
                      fit: BoxFit.cover,
                    ),
                  )
                else
                  Container(
                    height: 90,
                    width: 120,
                    color: Colors.black12,
                    child: const Icon(Icons.image_not_supported),
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        r.category,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      Text(r.description),
                      Text(
                        'Location: ${r.latitude.toStringAsFixed(5)}, ${r.longitude.toStringAsFixed(5)}',
                      ),
                      Wrap(
                        spacing: 8,
                        children: <Widget>[
                          Chip(label: Text('Status: ${r.status}')),
                          Chip(label: Text('Priority: ${r.priority}')),
                          Chip(
                            label: Text(
                              'Worker: ${r.assignedWorker?.isEmpty ?? true ? '-' : r.assignedWorker}',
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                StreamBuilder<List<WorkerItem>>(
                  stream: widget.service.workersStream(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<WorkerItem>> workerSnap,
                      ) {
                        final List<WorkerItem> workers =
                            workerSnap.data ?? const <WorkerItem>[];
                        return DropdownButton<String>(
                          value: r.assignedWorker,
                          hint: const Text('Assign worker'),
                          items: workers
                              .map(
                                (WorkerItem worker) => DropdownMenuItem<String>(
                                  value: worker.id,
                                  child: Text(worker.name),
                                ),
                              )
                              .toList(growable: false),
                          onChanged: _busy
                              ? null
                              : (String? workerId) {
                                  if (workerId == null) {
                                    return;
                                  }
                                  _run(
                                    () => widget.service.assignWorker(
                                      report: r,
                                      workerId: workerId,
                                    ),
                                  );
                                },
                        );
                      },
                ),
                FilledButton.tonal(
                  onPressed: _busy || r.status != 'Assigned'
                      ? null
                      : () => _run(() => widget.service.startWork(report: r)),
                  child: const Text('Start Work'),
                ),
                FilledButton.tonal(
                  onPressed: _busy || r.status != 'In Progress'
                      ? null
                      : () => _run(
                          () => widget.service.moveToUnderReview(report: r),
                        ),
                  child: const Text('Move to Under Review'),
                ),
                FilledButton(
                  onPressed:
                      _busy ||
                          r.status != 'Under Review' ||
                          r.repairImageUrl.isEmpty
                      ? null
                      : () =>
                            _run(() => widget.service.verifyRepair(report: r)),
                  child: const Text('Verify Repair'),
                ),
                if (r.repairImageUrl.isNotEmpty)
                  OutlinedButton(
                    onPressed: () {
                      showDialog<void>(
                        context: context,
                        builder: (_) => Dialog(
                          child: Image.network(
                            r.repairImageUrl,
                            fit: BoxFit.contain,
                          ),
                        ),
                      );
                    },
                    child: const Text('View Repair Image'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class WorkersTab extends StatelessWidget {
  const WorkersTab({super.key, required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<WorkerItem>>(
      stream: service.workersStream(),
      builder: (BuildContext context, AsyncSnapshot<List<WorkerItem>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<WorkerItem> workers = snapshot.data!;

        return ListView.builder(
          itemCount: workers.length,
          itemBuilder: (BuildContext context, int index) {
            final WorkerItem w = workers[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Card(
                child: ListTile(
                  title: Text(w.name),
                  subtitle: Text(
                    'Assigned: ${w.assignedTasks} • Completed: ${w.completedTasks} • Credibility: ${w.credibilityScore.toStringAsFixed(2)}',
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}

class MapTab extends StatelessWidget {
  const MapTab({super.key, required this.service});

  final AdminService service;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ReportItem>>(
      stream: service.reportsStream(limit: 300),
      builder: (BuildContext context, AsyncSnapshot<List<ReportItem>> snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final List<ReportItem> reports = snapshot.data!;

        final Set<Marker> markers = reports.map((ReportItem r) {
          return Marker(
            markerId: MarkerId(r.id),
            position: LatLng(r.latitude, r.longitude),
            icon: BitmapDescriptor.defaultMarkerWithHue(_statusHue(r.status)),
            onTap: () {
              showDialog<void>(
                context: context,
                builder: (_) => AlertDialog(
                  title: Text(r.category),
                  content: Text(
                    '${r.description}\n\nStatus: ${r.status}\nPriority: ${r.priority}\nAssigned: ${r.assignedWorker ?? '-'}',
                  ),
                ),
              );
            },
          );
        }).toSet();

        return GoogleMap(
          initialCameraPosition: const CameraPosition(
            target: LatLng(17.6599, 75.9064),
            zoom: 12,
          ),
          markers: markers,
        );
      },
    );
  }

  double _statusHue(String status) {
    switch (status) {
      case 'Reported':
        return BitmapDescriptor.hueRed;
      case 'Assigned':
        return BitmapDescriptor.hueYellow;
      case 'In Progress':
      case 'Under Review':
        return BitmapDescriptor.hueBlue;
      case 'Fixed':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueAzure;
    }
  }
}

class AdminService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get reportsCollection =>
      _firestore.collection('reports');
  CollectionReference<Map<String, dynamic>> get workersCollection =>
      _firestore.collection('workers');

  Stream<List<ReportItem>> reportsStream({int limit = 25}) {
    return reportsCollection
        .orderBy('timestamp', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (QuerySnapshot<Map<String, dynamic>> snap) =>
              snap.docs.map(ReportItem.fromDoc).toList(growable: false),
        );
  }

  Future<List<ReportItem>> fetchReportsPage({
    DocumentSnapshot<Map<String, dynamic>>? after,
    int limit = 25,
  }) async {
    Query<Map<String, dynamic>> query = reportsCollection
        .orderBy('timestamp', descending: true)
        .limit(limit);
    if (after != null) {
      query = query.startAfterDocument(after);
    }
    final QuerySnapshot<Map<String, dynamic>> snap = await query.get();
    return snap.docs.map(ReportItem.fromDoc).toList(growable: false);
  }

  Stream<List<WorkerItem>> workersStream() {
    return workersCollection.snapshots().map(
      (QuerySnapshot<Map<String, dynamic>> snap) =>
          snap.docs.map(WorkerItem.fromDoc).toList(growable: false),
    );
  }

  Future<void> assignWorker({
    required ReportItem report,
    required String workerId,
  }) async {
    await _transition(
      report: report,
      nextStatus: 'Assigned',
      updates: <String, dynamic>{
        'assigned_worker': workerId,
        'assigned_at': FieldValue.serverTimestamp(),
      },
      notifyType: 'Worker Assigned',
    );
  }

  Future<void> startWork({required ReportItem report}) {
    return _transition(
      report: report,
      nextStatus: 'In Progress',
      updates: <String, dynamic>{'started_at': FieldValue.serverTimestamp()},
      notifyType: 'Report Status Updated',
    );
  }

  Future<void> moveToUnderReview({required ReportItem report}) {
    return _transition(
      report: report,
      nextStatus: 'Under Review',
      updates: <String, dynamic>{
        'under_review_at': FieldValue.serverTimestamp(),
      },
      notifyType: 'Report Status Updated',
    );
  }

  Future<void> verifyRepair({required ReportItem report}) {
    return _transition(
      report: report,
      nextStatus: 'Fixed',
      updates: <String, dynamic>{
        'completion_timestamp': FieldValue.serverTimestamp(),
      },
      notifyType: 'Repair Verified',
    );
  }

  Future<void> _transition({
    required ReportItem report,
    required String nextStatus,
    required Map<String, dynamic> updates,
    required String notifyType,
  }) async {
    if (!_isAllowedTransition(report.status, nextStatus)) {
      throw StateError('Invalid transition: ${report.status} -> $nextStatus');
    }

    final DocumentReference<Map<String, dynamic>> ref = reportsCollection.doc(
      report.id,
    );
    await ref.update(<String, dynamic>{
      ...updates,
      'status': nextStatus,
      'timestamp': FieldValue.serverTimestamp(),
    });

    await _notify(
      userId: report.reporterId,
      title: notifyType,
      body: 'Report ${report.id} moved to $nextStatus.',
      reportId: report.id,
      type: notifyType,
    );

    if ((report.assignedWorker ?? '').isNotEmpty) {
      await _notify(
        userId: report.assignedWorker!,
        title: notifyType,
        body: 'Task ${report.id} moved to $nextStatus.',
        reportId: report.id,
        type: notifyType,
      );
    }
  }

  bool _isAllowedTransition(String current, String next) {
    const List<String> flow = <String>[
      'Reported',
      'Assigned',
      'In Progress',
      'Under Review',
      'Fixed',
    ];
    final int currentIndex = flow.indexOf(current);
    final int nextIndex = flow.indexOf(next);
    return currentIndex >= 0 && nextIndex == currentIndex + 1;
  }

  Future<void> _notify({
    required String userId,
    required String title,
    required String body,
    required String type,
    required String reportId,
  }) async {
    if (userId.isEmpty) {
      return;
    }
    await _firestore.collection('notifications').add(<String, dynamic>{
      'user_id': userId,
      'title': title,
      'body': body,
      'report_id': reportId,
      'type': type,
      'read': false,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }
}

class ReportItem {
  const ReportItem({
    required this.id,
    required this.reporterId,
    required this.imageUrl,
    required this.category,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.status,
    required this.priority,
    required this.timestamp,
    required this.rawDoc,
    this.assignedWorker,
    this.repairImageUrl = '',
  });

  final String id;
  final String reporterId;
  final String imageUrl;
  final String category;
  final String description;
  final double latitude;
  final double longitude;
  final String status;
  final String priority;
  final String? assignedWorker;
  final String repairImageUrl;
  final DateTime timestamp;
  final QueryDocumentSnapshot<Map<String, dynamic>> rawDoc;

  factory ReportItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return ReportItem(
      id: data['report_id'] as String? ?? doc.id,
      reporterId: data['reporter_id'] as String? ?? '',
      imageUrl: data['image_url'] as String? ?? '',
      category: data['category'] as String? ?? 'Unknown',
      description: data['description'] as String? ?? '',
      latitude: (data['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (data['longitude'] as num?)?.toDouble() ?? 0,
      status: data['status'] as String? ?? 'Reported',
      priority: data['priority'] as String? ?? 'low',
      assignedWorker: data['assigned_worker'] as String?,
      repairImageUrl: data['repair_image_url'] as String? ?? '',
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
      rawDoc: doc,
    );
  }
}

class WorkerItem {
  const WorkerItem({
    required this.id,
    required this.name,
    required this.assignedTasks,
    required this.completedTasks,
    required this.credibilityScore,
  });

  final String id;
  final String name;
  final int assignedTasks;
  final int completedTasks;
  final double credibilityScore;

  factory WorkerItem.fromDoc(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final Map<String, dynamic> data = doc.data();
    return WorkerItem(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      assignedTasks: (data['assigned_tasks'] as num?)?.toInt() ?? 0,
      completedTasks: (data['completed_tasks'] as num?)?.toInt() ?? 0,
      credibilityScore: (data['credibility_score'] as num?)?.toDouble() ?? 0,
    );
  }
}

class _LoadingPage extends StatelessWidget {
  const _LoadingPage();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
=======
        useMaterial3: true,
        colorScheme: colorScheme,
        scaffoldBackgroundColor: _background,
        cardTheme: CardThemeData(
          color: _card,
          elevation: 3,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          margin: EdgeInsets.zero,
        ),
        textTheme: Theme.of(
          context,
        ).textTheme.apply(bodyColor: _text, displayColor: _text),
        appBarTheme: const AppBarTheme(
          backgroundColor: _background,
          foregroundColor: _text,
          elevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white70,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _primary),
          ),
        ),
      ),
      home: const DashboardScreen(),
    );
  }
}
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
