import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/firestore_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key, required this.reports});

  final List<DashboardReport> reports;

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  DashboardReport? _selectedReport;

  @override
  Widget build(BuildContext context) {
    final List<DashboardReport> mappableReports = widget.reports
        .where((DashboardReport report) => report.hasValidLocation)
        .toList(growable: false);
    final LatLng center = mappableReports.isNotEmpty
        ? LatLng(
            mappableReports.first.latitude,
            mappableReports.first.longitude,
          )
        : const LatLng(17.6599, 75.9064);

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
          const Text(
            'City Issue Map',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: Color(0xFF37393A),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: SizedBox.expand(
                child: mappableReports.isEmpty
                    ? Container(
                        color: const Color(0xFFF7F7F7),
                        alignment: Alignment.center,
                        child: const Text('No report markers available'),
                      )
                    : FlutterMap(
                        options: MapOptions(
                          initialCenter: center,
                          initialZoom: 12,
                          interactionOptions: const InteractionOptions(
                            flags: InteractiveFlag.all,
                          ),
                        ),
                        children: <Widget>[
                          TileLayer(
                            urlTemplate:
                                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'solapur_admin_dashboard',
                          ),
                          MarkerLayer(
                            markers: mappableReports
                                .map(
                                  (DashboardReport report) => Marker(
                                    point: LatLng(
                                      report.latitude,
                                      report.longitude,
                                    ),
                                    width: 56,
                                    height: 56,
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(
                                          () => _selectedReport = report,
                                        );
                                      },
                                      child: Icon(
                                        Icons.location_on,
                                        size: 40,
                                        color: _priorityColor(
                                          report.priority,
                                        ),
                                      ),
                                    ),
                                  ),
                                )
                                .toList(growable: false),
                          ),
                        ],
                      ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFF7F7F7),
              borderRadius: BorderRadius.circular(16),
            ),
            child: _selectedReport == null
                ? const Text('Select a marker to view report details')
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        _selectedReport!.displayTitle,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 8),
                      Text(_selectedReport!.description),
                      const SizedBox(height: 8),
                      Text('Status: ${_selectedReport!.status}'),
                      Text(
                        'Assigned worker: ${_selectedReport!.assignedWorkerName.isEmpty ? 'Unassigned' : _selectedReport!.assignedWorkerName}',
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
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
