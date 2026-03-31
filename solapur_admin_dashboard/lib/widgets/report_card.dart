import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class ReportCard extends StatefulWidget {
  const ReportCard({
    super.key,
    required this.report,
    required this.workers,
    required this.isBusy,
    required this.onAssign,
    required this.onStatusUpdate,
  });

  final DashboardReport report;
  final List<DashboardWorker> workers;
  final bool isBusy;
  final Future<void> Function(DashboardWorker worker) onAssign;
  final Future<void> Function(String status) onStatusUpdate;

  @override
  State<ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends State<ReportCard> {
  String? _selectedWorkerId;

  @override
  void initState() {
    super.initState();
    _selectedWorkerId = widget.report.assignedWorkerId.isEmpty
        ? null
        : widget.report.assignedWorkerId;
  }

  @override
  void didUpdateWidget(covariant ReportCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.report.assignedWorkerId != widget.report.assignedWorkerId) {
      _selectedWorkerId = widget.report.assignedWorkerId.isEmpty
          ? null
          : widget.report.assignedWorkerId;
    }
  }

  @override
  Widget build(BuildContext context) {
    final DashboardWorker? selectedWorker = widget.workers
        .cast<DashboardWorker?>()
        .firstWhere(
          (DashboardWorker? worker) => worker?.id == _selectedWorkerId,
          orElse: () => null,
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              widget.report.displayTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(widget.report.description),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: <Widget>[
                _infoChip(context, 'Status', widget.report.status),
                _infoChip(
                  context,
                  'Priority',
                  widget.report.priority.toUpperCase(),
                ),
                _infoChip(context, 'Category', widget.report.category),
                _infoChip(
                  context,
                  'Worker',
                  widget.report.assignedWorkerName.isEmpty
                      ? 'Unassigned'
                      : widget.report.assignedWorkerName,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Location: ${widget.report.latitude.toStringAsFixed(5)}, ${widget.report.longitude.toStringAsFixed(5)}',
            ),
            const SizedBox(height: 14),
            Row(
              children: <Widget>[
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _selectedWorkerId,
                    decoration: const InputDecoration(
                      labelText: 'Assign worker',
                    ),
                    items: widget.workers
                        .map(
                          (DashboardWorker worker) => DropdownMenuItem<String>(
                            value: worker.id,
                            child: Text(worker.name),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: widget.isBusy
                        ? null
                        : (String? value) {
                            setState(() => _selectedWorkerId = value);
                          },
                  ),
                ),
                const SizedBox(width: 12),
                FilledButton(
                  onPressed: widget.isBusy || selectedWorker == null
                      ? null
                      : () => widget.onAssign(selectedWorker),
                  child: widget.isBusy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Assign'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: <Widget>[
                OutlinedButton(
                  onPressed: widget.isBusy
                      ? null
                      : () => widget.onStatusUpdate('Assigned'),
                  child: const Text('Assign'),
                ),
                OutlinedButton(
                  onPressed: widget.isBusy
                      ? null
                      : () => widget.onStatusUpdate('In Progress'),
                  child: const Text('Mark In Progress'),
                ),
                FilledButton.tonal(
                  onPressed: widget.isBusy || widget.report.status == 'Fixed'
                      ? null
                      : () => widget.onStatusUpdate('Fixed'),
                  child: const Text('Mark Fixed'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoChip(BuildContext context, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white70,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
