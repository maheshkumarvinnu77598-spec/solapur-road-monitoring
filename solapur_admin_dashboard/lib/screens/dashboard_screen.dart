import 'package:flutter/material.dart';

import '../services/firestore_service.dart';
import '../widgets/stat_card.dart';
import 'map_screen.dart';
import 'workers_screen.dart';

const Color _sidebarColor = Color(0xFF2F5D73);
const Color _activeColor = Color(0xFFD88A4D);
const Color _pageBackground = Color(0xFFF2F3F5);
const Color _panelColor = Colors.white;
const Color _textColor = Color(0xFF37393A);

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final FirestoreService _firestoreService = FirestoreService();

  int _selectedIndex = 0;
  String? _busyReportId;
  String? _busyWorkerId;
  String _statusFilter = 'All';
  String _categoryFilter = 'All';
  String _priorityFilter = 'All';
  final Map<String, String?> _selectedWorkers = <String, String?>{};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _pageBackground,
      body: SafeArea(
        child: StreamBuilder<List<DashboardWorker>>(
          stream: _firestoreService.workersStream(),
          builder:
              (
                BuildContext context,
                AsyncSnapshot<List<DashboardWorker>> workersSnapshot,
              ) {
                return StreamBuilder<List<DashboardReport>>(
                  stream: _firestoreService.reportsStream(),
                  builder:
                      (
                        BuildContext context,
                        AsyncSnapshot<List<DashboardReport>> reportsSnapshot,
                      ) {
                        if (workersSnapshot.hasError ||
                            reportsSnapshot.hasError) {
                          return const Center(
                            child: Text('Failed to load admin data'),
                          );
                        }
                        if (!workersSnapshot.hasData ||
                            !reportsSnapshot.hasData) {
                          return const Center(
                            child: CircularProgressIndicator(),
                          );
                        }

                        final List<DashboardWorker> workers =
                            workersSnapshot.data!;
                        final List<DashboardReport> reports =
                            reportsSnapshot.data!.toList(growable: true)..sort(
                              (DashboardReport a, DashboardReport b) =>
                                  a.id.compareTo(b.id),
                            );

                        return Row(
                          children: <Widget>[
                            _Sidebar(
                              selectedIndex: _selectedIndex,
                              onSelected: (int index) {
                                setState(() => _selectedIndex = index);
                              },
                              onLogout: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Logged out')),
                                );
                              },
                            ),
                            Expanded(
                              child: Column(
                                children: <Widget>[
                                  _Header(
                                    pageTitle: _pageTitleForIndex(
                                      _selectedIndex,
                                    ),
                                    action: _selectedIndex == 3
                                        ? FilledButton.icon(
                                            onPressed: () {
                                              _showAddWorkerDialog(context);
                                            },
                                            icon: const Icon(Icons.add),
                                            label: const Text(
                                              'Create Worker',
                                            ),
                                            style: FilledButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFF77B6EA,
                                              ),
                                              foregroundColor: Colors.white,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                    vertical: 14,
                                                  ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                            ),
                                          )
                                        : null,
                                    onLogout: () {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        const SnackBar(
                                          content: Text('Logged out'),
                                        ),
                                      );
                                    },
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        24,
                                        0,
                                        24,
                                        24,
                                      ),
                                      child: _buildPage(
                                        context: context,
                                        reports: reports,
                                        workers: workers,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                );
              },
        ),
      ),
    );
  }

  Widget _buildPage({
    required BuildContext context,
    required List<DashboardReport> reports,
    required List<DashboardWorker> workers,
  }) {
    switch (_selectedIndex) {
      case 0:
        return _buildDashboardPage(reports: reports, workers: workers);
      case 1:
        return _buildReportsPage(
          context: context,
          reports: reports,
          workers: workers,
        );
      case 2:
        return MapScreen(reports: reports);
      case 3:
        return WorkersScreen(
          workers: workers,
          busyWorkerId: _busyWorkerId,
          onAddWorker: () {
            _showAddWorkerDialog(context);
          },
          onGenerateIdCard: (DashboardWorker worker) {
            _showWorkerIdCard(context, worker);
          },
          onDeleteWorker: (DashboardWorker worker) async {
            final ScaffoldMessengerState messenger = ScaffoldMessenger.of(
              context,
            );
            await _withBusyWorker(worker.id, () async {
              await _firestoreService.deleteWorker(worker: worker);
              if (!mounted) {
                return;
              }
              messenger.showSnackBar(
                SnackBar(content: Text('${worker.name} deleted')),
              );
            });
          },
        );
      case 4:
        return _buildPlaceholderPage(
          title: 'Support',
          body:
              'Support requests, escalation flow, and citizen communication tools live here.',
        );
      case 5:
        return _buildPlaceholderPage(
          title: 'Settings',
          body:
              'System preferences, dashboard configuration, and admin controls live here.',
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildDashboardPage({
    required List<DashboardReport> reports,
    required List<DashboardWorker> workers,
  }) {
    final List<_DashboardStat> stats = <_DashboardStat>[
      _DashboardStat(
        'Total Reports',
        '${reports.length}',
        const Color(0xFF77B6EA),
      ),
      _DashboardStat(
        'Reported',
        '${_countStatus(reports, 'Reported')}',
        _activeColor,
      ),
      _DashboardStat(
        'Assigned',
        '${_countStatus(reports, 'Assigned')}',
        const Color(0xFF9F6D52),
      ),
      _DashboardStat(
        'In Progress',
        '${_countStatus(reports, 'In Progress')}',
        const Color(0xFF5E8DAA),
      ),
      _DashboardStat(
        'Fixed',
        '${_countStatus(reports, 'Fixed')}',
        const Color(0xFF5D9A7A),
      ),
      _DashboardStat(
        'Resolved',
        '${_countStatus(reports, 'Resolved')}',
        const Color(0xFF7A8C99),
      ),
    ];

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: stats.length,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.9,
            ),
            itemBuilder: (BuildContext context, int index) {
              final _DashboardStat stat = stats[index];
              return StatCard(
                label: stat.label,
                value: stat.value,
                highlight: stat.color,
              );
            },
          ),
          const SizedBox(height: 24),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Expanded(
                flex: 2,
                child: _whitePanel(child: _buildQuickActivity(reports)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _whitePanel(child: _buildWorkerSnapshot(workers)),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActivity(List<DashboardReport> reports) {
    final List<DashboardReport> latest = reports
        .take(6)
        .toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Recent Reports',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 16),
        if (latest.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No reports available'),
          )
        else
          ...latest.map(
            (DashboardReport report) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F7F7),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFE4E7EA)),
              ),
              child: Row(
                children: <Widget>[
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: _priorityColor(report.priority),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          report.displayTitle,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          report.status,
                          style: const TextStyle(color: Color(0xFF717171)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildWorkerSnapshot(List<DashboardWorker> workers) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Workers',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: _textColor,
          ),
        ),
        const SizedBox(height: 16),
        if (workers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Text('No workers available'),
          )
        else
          ...workers
              .take(6)
              .map(
                (DashboardWorker worker) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: <Widget>[
                      CircleAvatar(
                        backgroundColor: _sidebarColor,
                        child: Text(
                          worker.name.isEmpty
                              ? '?'
                              : worker.name[0].toUpperCase(),
                          style: const TextStyle(color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              worker.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'Active tasks: ${worker.activeTasks}',
                              style: const TextStyle(color: Color(0xFF717171)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ],
    );
  }

  Widget _buildReportsPage({
    required BuildContext context,
    required List<DashboardReport> reports,
    required List<DashboardWorker> workers,
  }) {
    final List<DashboardReport> filteredReports = reports
        .where(_matchesFilters)
        .toList(growable: false);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _buildFilterRow(reports),
        const SizedBox(height: 16),
        Expanded(
          child: _whitePanel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'Report Management',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: filteredReports.isEmpty
                      ? const Center(child: Text('No reports found'))
                      : SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(minWidth: 1180),
                            child: SingleChildScrollView(
                              child: DataTable(
                                headingRowColor: WidgetStateProperty.all(
                                  const Color(0xFFF0F2F4),
                                ),
                                dataRowMinHeight: 108,
                                dataRowMaxHeight: 138,
                                columnSpacing: 20,
                                headingTextStyle: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: _textColor,
                                ),
                                columns: const <DataColumn>[
                                  DataColumn(label: Text('Report ID')),
                                  DataColumn(label: Text('Category')),
                                  DataColumn(label: Text('Priority')),
                                  DataColumn(label: Text('Status')),
                                  DataColumn(label: Text('Location')),
                                  DataColumn(label: Text('Assign Worker')),
                                  DataColumn(label: Text('View Details')),
                                ],
                                rows: filteredReports
                                    .map(
                                      (DashboardReport report) => DataRow(
                                        cells: <DataCell>[
                                          DataCell(Text(report.id)),
                                          DataCell(Text(report.category)),
                                          DataCell(
                                            _priorityBadge(report.priority),
                                          ),
                                          DataCell(_statusBadge(report.status)),
                                          DataCell(
                                            Text(
                                              '${report.latitude.toStringAsFixed(4)}, ${report.longitude.toStringAsFixed(4)}',
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: FittedBox(
                                                alignment: Alignment.centerLeft,
                                                fit: BoxFit.scaleDown,
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: 180,
                                                      child: DropdownButtonFormField<String>(
                                                        initialValue:
                                                            _selectedWorkers[report
                                                                .id] ??
                                                            (report
                                                                    .assignedWorkerId
                                                                    .isEmpty
                                                                ? null
                                                                : report
                                                                      .assignedWorkerId),
                                                        decoration:
                                                            const InputDecoration(
                                                              isDense: true,
                                                              contentPadding:
                                                                  EdgeInsets.symmetric(
                                                                    horizontal:
                                                                        12,
                                                                    vertical:
                                                                        12,
                                                                  ),
                                                            ),
                                                        items: workers
                                                            .map(
                                                              (
                                                                DashboardWorker
                                                                worker,
                                                              ) =>
                                                                  DropdownMenuItem<
                                                                    String
                                                                  >(
                                                                    value:
                                                                        worker
                                                                            .id,
                                                                    child: Text(
                                                                      worker
                                                                          .name,
                                                                    ),
                                                                  ),
                                                            )
                                                            .toList(
                                                              growable: false,
                                                            ),
                                                        onChanged:
                                                            _busyReportId ==
                                                                report.id
                                                            ? null
                                                            : (String? value) {
                                                                setState(() {
                                                                  _selectedWorkers[report
                                                                          .id] =
                                                                      value;
                                                                });
                                                              },
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 110,
                                                      child: ElevatedButton(
                                                        style: ElevatedButton.styleFrom(
                                                          backgroundColor:
                                                              _activeColor,
                                                          foregroundColor:
                                                              Colors.white,
                                                          shape: RoundedRectangleBorder(
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  10,
                                                                ),
                                                          ),
                                                        ),
                                                        onPressed:
                                                            _busyReportId ==
                                                                report.id
                                                            ? null
                                                            : () async {
                                                                final String
                                                                selectedId =
                                                                    _selectedWorkers[report
                                                                        .id] ??
                                                                    report
                                                                        .assignedWorkerId;
                                                                final DashboardWorker?
                                                                worker = workers
                                                                    .cast<
                                                                      DashboardWorker?
                                                                    >()
                                                                    .firstWhere(
                                                                      (
                                                                        DashboardWorker?
                                                                        item,
                                                                      ) =>
                                                                          item?.id ==
                                                                          selectedId,
                                                                      orElse: () =>
                                                                          null,
                                                                    );
                                                                if (worker ==
                                                                    null) {
                                                                  ScaffoldMessenger.of(
                                                                    context,
                                                                  ).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Text(
                                                                        'Select a worker first',
                                                                      ),
                                                                    ),
                                                                  );
                                                                  return;
                                                                }
                                                                await _withBusyReport(
                                                                  report.id,
                                                                  () async {
                                                                    await _firestoreService.assignWorker(
                                                                      reportId:
                                                                          report
                                                                              .id,
                                                                      worker:
                                                                          worker,
                                                                    );
                                                                  },
                                                                );
                                                              },
                                                        child:
                                                            _busyReportId ==
                                                                report.id
                                                            ? const SizedBox(
                                                                width: 16,
                                                                height: 16,
                                                                child: CircularProgressIndicator(
                                                                  strokeWidth:
                                                                      2,
                                                                  color: Colors
                                                                      .white,
                                                                ),
                                                              )
                                                            : const Text(
                                                                'Assign',
                                                              ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                          DataCell(
                                            Padding(
                                              padding: const EdgeInsets.all(8),
                                              child: FittedBox(
                                                alignment: Alignment.centerLeft,
                                                fit: BoxFit.scaleDown,
                                                child: Wrap(
                                                  spacing: 8,
                                                  runSpacing: 8,
                                                  children: <Widget>[
                                                    SizedBox(
                                                      width: 110,
                                                      child: _tableActionButton(
                                                        label: 'View',
                                                        onPressed: () {
                                                          _showReportDetails(
                                                            context,
                                                            report,
                                                          );
                                                        },
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 110,
                                                      child: _tableActionButton(
                                                        label: 'Progress',
                                                        onPressed:
                                                            _busyReportId ==
                                                                report.id
                                                            ? null
                                                            : () async {
                                                                await _withBusyReport(
                                                                  report.id,
                                                                  () => _firestoreService.updateStatus(
                                                                    reportId:
                                                                        report
                                                                            .id,
                                                                    status:
                                                                        'In Progress',
                                                                  ),
                                                                );
                                                              },
                                                      ),
                                                    ),
                                                    SizedBox(
                                                      width: 110,
                                                      child: _tableActionButton(
                                                        label: 'Fixed',
                                                        filled: true,
                                                        onPressed:
                                                            _busyReportId ==
                                                                    report.id ||
                                                                report.status ==
                                                                    'Fixed'
                                                            ? null
                                                            : () async {
                                                                await _withBusyReport(
                                                                  report.id,
                                                                  () => _firestoreService
                                                                      .markFixed(
                                                                        reportId:
                                                                            report.id,
                                                                      ),
                                                                );
                                                              },
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                    .toList(growable: false),
                              ),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow(List<DashboardReport> reports) {
    return Row(
      children: <Widget>[
        SizedBox(
          width: 220,
          child: _filterField(
            label: 'Status',
            value: _statusFilter,
            items: const <String>[
              'All',
              'Reported',
              'Assigned',
              'In Progress',
              'Fixed',
              'Resolved',
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _statusFilter = value);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: _filterField(
            label: 'Category',
            value: _categoryFilter,
            items: <String>[
              'All',
              ..._unique(
                reports.map((DashboardReport report) => report.category),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _categoryFilter = value);
              }
            },
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 220,
          child: _filterField(
            label: 'Priority',
            value: _priorityFilter,
            items: <String>[
              'All',
              ..._unique(
                reports.map((DashboardReport report) => report.priority),
              ),
            ],
            onChanged: (String? value) {
              if (value != null) {
                setState(() => _priorityFilter = value);
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _filterField({
    required String label,
    required String value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: ''),
      hint: Text(label),
      items: items
          .map(
            (String item) =>
                DropdownMenuItem<String>(value: item, child: Text(item)),
          )
          .toList(growable: false),
      onChanged: onChanged,
    );
  }

  Widget _buildPlaceholderPage({required String title, required String body}) {
    return _whitePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _textColor,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            body,
            style: const TextStyle(fontSize: 15, color: Color(0xFF5F6467)),
          ),
        ],
      ),
    );
  }

  Widget _whitePanel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _panelColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _priorityBadge(String priority) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: _priorityColor(priority).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        priority.toUpperCase(),
        style: TextStyle(
          color: _priorityColor(priority),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _statusBadge(String status) {
    final Color color = switch (status) {
      'Assigned' => const Color(0xFFD88A4D),
      'In Progress' => const Color(0xFF5E8DAA),
      'Fixed' => const Color(0xFF5D9A7A),
      'Resolved' => const Color(0xFF7A8C99),
      _ => const Color(0xFFB06363),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        status,
        style: TextStyle(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _tableActionButton({
    required String label,
    required VoidCallback? onPressed,
    bool filled = false,
  }) {
    final ButtonStyle style = filled
        ? ElevatedButton.styleFrom(
            backgroundColor: _activeColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          )
        : OutlinedButton.styleFrom(
            foregroundColor: _sidebarColor,
            side: const BorderSide(color: Color(0xFFD5D9DE)),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          );

    return SizedBox(
      height: 38,
      child: filled
          ? ElevatedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            )
          : OutlinedButton(
              onPressed: onPressed,
              style: style,
              child: Text(label),
            ),
    );
  }

  Future<void> _withBusyReport(
    String reportId,
    Future<void> Function() action,
  ) async {
    setState(() => _busyReportId = reportId);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busyReportId = null);
      }
    }
  }

  Future<void> _withBusyWorker(
    String workerId,
    Future<void> Function() action,
  ) async {
    setState(() => _busyWorkerId = workerId);
    try {
      await action();
    } finally {
      if (mounted) {
        setState(() => _busyWorkerId = null);
      }
    }
  }

  String _generateWorkerId() {
    final int timestamp = DateTime.now().millisecondsSinceEpoch;
    return 'W${timestamp.toString().substring(7)}';
  }

  void _showAddWorkerDialog(BuildContext context) {
    String name = '';
    String workerId = _generateWorkerId();
    String zone = '';
    String role = '';
    String password = '';
    bool isSubmitting = false;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) {
        final NavigatorState navigator = Navigator.of(dialogContext);
        return StatefulBuilder(
          builder: (
            BuildContext builderContext,
            void Function(void Function()) setDialogState,
          ) {
            Future<void> submit() async {
              final String normalizedName = name.trim();
              final String normalizedWorkerId = workerId.trim();
              final String normalizedZone = zone.trim();
              final String normalizedRole = role.trim();
              final String normalizedPassword = password.trim();

              if (normalizedName.isEmpty ||
                  normalizedWorkerId.isEmpty ||
                  normalizedZone.isEmpty ||
                  normalizedRole.isEmpty) {
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text('Name, Worker ID, Zone, and Role are required'),
                  ),
                );
                return;
              }

              setDialogState(() => isSubmitting = true);

              try {
                await _withBusyWorker(normalizedWorkerId, () {
                  return _firestoreService.createWorker(
                    workerId: normalizedWorkerId,
                    name: normalizedName,
                    zone: normalizedZone,
                    role: normalizedRole,
                    password: normalizedPassword.isEmpty
                        ? normalizedWorkerId
                        : normalizedPassword,
                  );
                });

                if (!mounted) {
                  return;
                }

                navigator.pop();
                Future<void>.delayed(Duration.zero, () {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Worker created successfully ($normalizedWorkerId)',
                      ),
                    ),
                  );
                });
              } catch (_) {
                if (!mounted) {
                  return;
                }
                messenger.showSnackBar(
                  const SnackBar(content: Text('Failed to create worker')),
                );
              } finally {
                if (dialogContext.mounted) {
                  setDialogState(() => isSubmitting = false);
                }
              }
            }

            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              title: const Text('Add Worker'),
              content: SizedBox(
                width: 420,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      TextFormField(
                        initialValue: name,
                        decoration: const InputDecoration(labelText: 'Name'),
                        textInputAction: TextInputAction.next,
                        onChanged: (String value) => name = value,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: workerId,
                        decoration: const InputDecoration(
                          labelText: 'Worker ID',
                        ),
                        textInputAction: TextInputAction.next,
                        onChanged: (String value) => workerId = value,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: zone,
                        decoration: const InputDecoration(labelText: 'Zone'),
                        textInputAction: TextInputAction.next,
                        onChanged: (String value) => zone = value,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        textInputAction: TextInputAction.next,
                        onChanged: (String value) => role = value,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        initialValue: password,
                        decoration: const InputDecoration(
                          labelText: 'Password (optional)',
                        ),
                        obscureText: true,
                        onChanged: (String value) => password = value,
                        onFieldSubmitted: (_) {
                          if (!isSubmitting) {
                            submit();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: isSubmitting
                      ? null
                      : () => Navigator.of(dialogContext).pop(),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _activeColor,
                    foregroundColor: Colors.white,
                  ),
                  onPressed: isSubmitting ? null : submit,
                  child: isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showReportDetails(BuildContext context, DashboardReport report) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(report.displayTitle),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(report.description),
                const SizedBox(height: 12),
                Text('Report ID: ${report.id}'),
                Text('Status: ${report.status}'),
                Text('Priority: ${report.priority.toUpperCase()}'),
                Text('Category: ${report.category}'),
                Text(
                  'Assigned worker: ${report.assignedWorkerName.isEmpty ? 'Unassigned' : report.assignedWorkerName}',
                ),
                const SizedBox(height: 8),
                Text(
                  'Location: ${report.latitude.toStringAsFixed(5)}, ${report.longitude.toStringAsFixed(5)}',
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showWorkerIdCard(BuildContext context, DashboardWorker worker) {
    showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          child: Container(
            width: 380,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                const Text(
                  'City Command Centre',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Admin web console',
                  style: TextStyle(color: Color(0xFF6B7074)),
                ),
                const SizedBox(height: 20),
                Text(
                  worker.name,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text('Worker ID: ${worker.id}'),
                Text('Zone: ${worker.zone}'),
                Text('Role: ${worker.role}'),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _pageTitleForIndex(int index) {
    switch (index) {
      case 0:
        return 'Dashboard Overview';
      case 1:
        return 'Report Management';
      case 2:
        return 'Map Monitoring';
      case 3:
        return 'Worker Management';
      case 4:
        return 'Support';
      case 5:
        return 'Settings';
      default:
        return 'Dashboard';
    }
  }

  int _countStatus(List<DashboardReport> reports, String status) {
    return reports
        .where((DashboardReport report) => report.status == status)
        .length;
  }

  List<String> _unique(Iterable<String> values) {
    final List<String> items =
        values
            .where((String value) => value.trim().isNotEmpty)
            .toSet()
            .toList(growable: false)
          ..sort();
    return items;
  }

  bool _matchesFilters(DashboardReport report) {
    return (_statusFilter == 'All' || report.status == _statusFilter) &&
        (_categoryFilter == 'All' || report.category == _categoryFilter) &&
        (_priorityFilter == 'All' ||
            report.priority.toLowerCase() == _priorityFilter.toLowerCase());
  }

  Color _priorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
      case 'critical':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      default:
        return Colors.green;
    }
  }
}

class _Sidebar extends StatelessWidget {
  const _Sidebar({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });

  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    const List<String> labels = <String>[
      'Dashboard',
      'Reports',
      'Map',
      'Workers',
      'Support',
      'Settings',
    ];

    const List<IconData> icons = <IconData>[
      Icons.dashboard_outlined,
      Icons.receipt_long_outlined,
      Icons.map_outlined,
      Icons.groups_outlined,
      Icons.support_agent_outlined,
      Icons.settings_outlined,
    ];

    return Container(
      width: 260,
      color: _sidebarColor,
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'City Command Centre',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Admin web console',
            style: TextStyle(color: Color(0xFFD6E4EC), fontSize: 14),
          ),
          const SizedBox(height: 28),
          ...List<Widget>.generate(labels.length, (int index) {
            final bool active = selectedIndex == index;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => onSelected(index),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: active ? _activeColor : Colors.transparent,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: <Widget>[
                      Icon(icons[index], color: Colors.white),
                      const SizedBox(width: 12),
                      Text(
                        labels[index],
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: _sidebarColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              onPressed: onLogout,
              icon: const Icon(Icons.logout),
              label: const Text(
                'Logout',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.pageTitle,
    required this.onLogout,
    this.action,
  });

  final String pageTitle;
  final VoidCallback onLogout;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 18),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              const Spacer(),
              const Expanded(
                flex: 3,
                child: Center(
                  child: Text(
                    'Solapur Road Monitoring System',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                      color: _textColor,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout, color: _textColor),
                    label: const Text(
                      'Logout',
                      style: TextStyle(
                        color: _textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Text(
                  pageTitle,
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    color: _textColor,
                  ),
                ),
              ),
              if (action != null) ...<Widget>[
                const SizedBox(width: 16),
                action!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardStat {
  const _DashboardStat(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}
