import 'package:flutter/material.dart';

import '../services/firestore_service.dart';

class WorkersScreen extends StatelessWidget {
  const WorkersScreen({
    super.key,
    required this.workers,
    required this.busyWorkerId,
    required this.onAddWorker,
    required this.onGenerateIdCard,
    required this.onDeleteWorker,
  });

  final List<DashboardWorker> workers;
  final String? busyWorkerId;
  final VoidCallback onAddWorker;
  final ValueChanged<DashboardWorker> onGenerateIdCard;
  final Future<void> Function(DashboardWorker worker) onDeleteWorker;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x14000000),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: double.infinity,
            child: Row(
              children: <Widget>[
                const Expanded(
                  child: Text(
                    'Workers',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF37393A),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF77B6EA),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const <BoxShadow>[
                      BoxShadow(
                        color: Color(0x2277B6EA),
                        blurRadius: 12,
                        offset: Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: onAddWorker,
                      child: const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            Icon(Icons.add, color: Colors.white, size: 18),
                            SizedBox(width: 8),
                            Text(
                              'Create Worker',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: workers.isEmpty
                ? const Center(child: Text('No workers found'))
                : SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minWidth: 920),
                      child: SingleChildScrollView(
                        child: DataTable(
                          headingRowColor: WidgetStateProperty.all(
                            const Color(0xFFF0F2F4),
                          ),
                          columnSpacing: 24,
                          headingTextStyle: const TextStyle(
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF37393A),
                          ),
                          columns: const <DataColumn>[
                            DataColumn(label: Text('Name')),
                            DataColumn(label: Text('Worker ID')),
                            DataColumn(label: Text('Zone')),
                            DataColumn(label: Text('Role')),
                            DataColumn(label: Text('Actions')),
                          ],
                          rows: workers
                              .map(
                                (DashboardWorker worker) => DataRow(
                                  cells: <DataCell>[
                                    DataCell(Text(worker.name)),
                                    DataCell(Text(worker.id)),
                                    DataCell(Text(worker.zone)),
                                    DataCell(Text(worker.role)),
                                    DataCell(
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: <Widget>[
                                          OutlinedButton(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: const Color(
                                                0xFF2F5D73,
                                              ),
                                              side: const BorderSide(
                                                color: Color(0xFFD5D9DE),
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: () =>
                                                onGenerateIdCard(worker),
                                            child: const Text(
                                              'Generate ID Card',
                                            ),
                                          ),
                                          ElevatedButton(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: const Color(
                                                0xFFD88A4D,
                                              ),
                                              foregroundColor: Colors.white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(10),
                                              ),
                                            ),
                                            onPressed: busyWorkerId == worker.id
                                                ? null
                                                : () => onDeleteWorker(worker),
                                            child: busyWorkerId == worker.id
                                                ? const SizedBox(
                                                    width: 16,
                                                    height: 16,
                                                    child:
                                                        CircularProgressIndicator(
                                                          strokeWidth: 2,
                                                          color: Colors.white,
                                                        ),
                                                  )
                                                : const Text('Delete Worker'),
                                          ),
                                        ],
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
    );
  }
}
