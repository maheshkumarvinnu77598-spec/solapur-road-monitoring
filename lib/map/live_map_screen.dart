import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/report_model.dart';
import '../reporting/report_repository.dart';
import '../ui_theme/app_theme.dart';

enum MapFilter { all, road, drainage, garbage, utility }

enum StatusFilter { all, reported, assigned, inProgress, underReview, fixed }

class LiveMapScreen extends StatefulWidget {
  const LiveMapScreen({super.key, required this.repository});

  final ReportRepository repository;

  @override
  State<LiveMapScreen> createState() => _LiveMapScreenState();
}

class _LiveMapScreenState extends State<LiveMapScreen> {
  static const ClusterManagerId _clusterId = ClusterManagerId('issues');

  MapFilter _filter = MapFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;
  GoogleMapController? _controller;
  Timer? _debounce;

  List<ReportModel> _reports = <ReportModel>[];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadDefault();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _loadDefault() async {
    await _loadBounds(
      minLatitude: 17.45,
      maxLatitude: 17.85,
      minLongitude: 75.70,
      maxLongitude: 76.10,
    );
  }

  Future<void> _loadBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async {
    if (!mounted) {
      return;
    }
    setState(() => _loading = true);

    try {
      final data = await widget.repository.fetchReportsInBounds(
        minLatitude: minLatitude,
        maxLatitude: maxLatitude,
        minLongitude: minLongitude,
        maxLongitude: maxLongitude,
      );
      if (!mounted) {
        return;
      }
      setState(() => _reports = data);
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _onCameraIdle() async {
    final GoogleMapController? controller = _controller;
    if (controller == null) {
      return;
    }
    final LatLngBounds bounds = await controller.getVisibleRegion();
    await _loadBounds(
      minLatitude: bounds.southwest.latitude,
      maxLatitude: bounds.northeast.latitude,
      minLongitude: bounds.southwest.longitude,
      maxLongitude: bounds.northeast.longitude,
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ReportModel> filtered = _reports
        .where((ReportModel r) => _matchesFilter(r.category))
        .where((ReportModel r) => _matchesStatusFilter(r.status))
        .toList(growable: false);

    final bool useClustering = filtered.length > 50;
    final Set<Marker> markers = filtered
        .map((ReportModel report) => _buildReportMarker(report, useClustering))
        .toSet();
    final Set<Circle> heatCircles = filtered.length > 500
        ? <Circle>{}
        : _buildHeatmapCircles(filtered);

    return Column(
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              _filterChip(MapFilter.all, 'All Issues'),
              _filterChip(MapFilter.road, 'Road Issues'),
              _filterChip(MapFilter.drainage, 'Drainage Issues'),
              _filterChip(MapFilter.garbage, 'Garbage Issues'),
              _filterChip(MapFilter.utility, 'Utility Issues'),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              _statusChip(StatusFilter.all, 'All Status'),
              _statusChip(StatusFilter.reported, 'Reported'),
              _statusChip(StatusFilter.assigned, 'Assigned'),
              _statusChip(StatusFilter.inProgress, 'In Progress'),
              _statusChip(StatusFilter.underReview, 'Under Review'),
              _statusChip(StatusFilter.fixed, 'Fixed'),
            ],
          ),
        ),
        Expanded(
          child: Stack(
            children: [
              RepaintBoundary(
                child: GoogleMap(
                  initialCameraPosition: const CameraPosition(
                    target: LatLng(17.6599, 75.9064),
                    zoom: 12,
                  ),
                  markers: markers,
                  circles: heatCircles,
                  myLocationEnabled: true,
                  myLocationButtonEnabled: true,
                  clusterManagers: useClustering
                      ? <ClusterManager>{
                          ClusterManager(clusterManagerId: _clusterId),
                        }
                      : const <ClusterManager>{},
                  onMapCreated: (GoogleMapController controller) {
                    _controller = controller;
                  },
                  onCameraMove: (_) {
                    _debounce?.cancel();
                  },
                  onCameraIdle: () {
                    _debounce?.cancel();
                    _debounce = Timer(const Duration(milliseconds: 350), () {
                      _onCameraIdle();
                    });
                  },
                ),
              ),
              if (_loading)
                const Align(
                  alignment: Alignment.topCenter,
                  child: Padding(
                    padding: EdgeInsets.only(top: 10),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _statusChip(StatusFilter filter, String label) {
    final bool selected = _statusFilter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppPalette.accent,
        onSelected: (_) => setState(() => _statusFilter = filter),
      ),
    );
  }

  Widget _filterChip(MapFilter filter, String label) {
    final bool selected = _filter == filter;
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        selectedColor: AppPalette.primary,
        onSelected: (_) => setState(() => _filter = filter),
      ),
    );
  }

  bool _matchesFilter(String category) {
    final String c = category.toLowerCase();
    switch (_filter) {
      case MapFilter.all:
        return true;
      case MapFilter.road:
        return c.contains('road') ||
            c.contains('pothole') ||
            c.contains('footpath');
      case MapFilter.drainage:
        return c.contains('drain') || c.contains('water logging');
      case MapFilter.garbage:
        return c.contains('garbage');
      case MapFilter.utility:
        return c.contains('street light');
    }
  }

  bool _matchesStatusFilter(String status) {
    switch (_statusFilter) {
      case StatusFilter.all:
        return true;
      case StatusFilter.reported:
        return status == 'Reported' || status == 'Pending';
      case StatusFilter.assigned:
        return status == 'Assigned';
      case StatusFilter.inProgress:
        return status == 'In Progress';
      case StatusFilter.underReview:
        return status == 'Under Review';
      case StatusFilter.fixed:
        return status == 'Fixed' || status == 'Resolved';
    }
  }

  double _markerHue(String status) {
    switch (status) {
      case 'Pending':
      case 'Reported':
        return BitmapDescriptor.hueRed;
      case 'Assigned':
        return BitmapDescriptor.hueYellow;
      case 'In Progress':
        return BitmapDescriptor.hueBlue;
      case 'Under Review':
        return BitmapDescriptor.hueOrange;
      case 'Resolved':
      case 'Fixed':
        return BitmapDescriptor.hueGreen;
      default:
        return BitmapDescriptor.hueYellow;
    }
  }

  Marker _buildReportMarker(ReportModel report, bool useClustering) {
    return Marker(
      markerId: MarkerId(report.id),
      clusterManagerId: useClustering ? _clusterId : null,
      position: LatLng(report.latitude, report.longitude),
      icon: BitmapDescriptor.defaultMarkerWithHue(_markerHue(report.status)),
      infoWindow: InfoWindow(
        title: report.category,
        snippet: '${report.priority.toUpperCase()} • ${report.status}',
      ),
      onTap: () => _openDetails(report),
    );
  }

  Set<Circle> _buildHeatmapCircles(List<ReportModel> reports) {
    final Map<String, List<ReportModel>> grouped =
        <String, List<ReportModel>>{};
    for (final ReportModel report in reports) {
      final String key =
          '${report.latitude.toStringAsFixed(3)},${report.longitude.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => <ReportModel>[]).add(report);
    }

    final Set<Circle> circles = <Circle>{};
    grouped.forEach((key, group) {
      final report = group.first;
      final int density = group.length;
      final Color color = density >= 5
          ? Colors.red.withAlpha(120)
          : density >= 3
          ? Colors.yellow.withAlpha(120)
          : Colors.green.withAlpha(120);

      circles.add(
        Circle(
          circleId: CircleId('heat-$key'),
          center: LatLng(report.latitude, report.longitude),
          radius: 60 + (density * 12),
          fillColor: color,
          strokeColor: Colors.transparent,
          strokeWidth: 0,
        ),
      );
    });
    return circles;
  }

  void _openDetails(ReportModel report) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (BuildContext context) {
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                report.category,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              Text(report.description),
              const SizedBox(height: 8),
              Text('Priority: ${report.priority}'),
              Text('Status: ${report.status}'),
              const SizedBox(height: 10),
              if (report.imageUrl.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Image.network(
                    report.imageUrl,
                    height: 160,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
