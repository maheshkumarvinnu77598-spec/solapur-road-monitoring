import 'dart:async';

import 'package:flutter/material.dart';
<<<<<<< HEAD
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../models/report_model.dart';
=======
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../models/report_model.dart';
import '../reporting/report_detail_screen.dart';
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
  static const ClusterManagerId _clusterId = ClusterManagerId('issues');

  MapFilter _filter = MapFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;
  GoogleMapController? _controller;
  Timer? _debounce;
=======
  static const LatLng _defaultCenter = LatLng(17.6599, 75.9064);

  final MapController _mapController = MapController();
  MapFilter _filter = MapFilter.all;
  StatusFilter _statusFilter = StatusFilter.all;
  Timer? _debounce;
  bool _isFetchingBounds = false;
  String? _lastBoundsKey;
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c

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
<<<<<<< HEAD
    _controller?.dispose();
=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    super.dispose();
  }

  Future<void> _loadDefault() async {
<<<<<<< HEAD
    await _loadBounds(
      minLatitude: 17.45,
      maxLatitude: 17.85,
      minLongitude: 75.70,
      maxLongitude: 76.10,
    );
=======
    try {
      await _loadBounds(
        minLatitude: 17.45,
        maxLatitude: 17.85,
        minLongitude: 75.70,
        maxLongitude: 76.10,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  }

  Future<void> _loadBounds({
    required double minLatitude,
    required double maxLatitude,
    required double minLongitude,
    required double maxLongitude,
  }) async {
<<<<<<< HEAD
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
=======
    final String boundsKey =
        '${minLatitude.toStringAsFixed(3)}:'
        '${maxLatitude.toStringAsFixed(3)}:'
        '${minLongitude.toStringAsFixed(3)}:'
        '${maxLongitude.toStringAsFixed(3)}';
    if (!mounted || _isFetchingBounds || _lastBoundsKey == boundsKey) {
      return;
    }
    _isFetchingBounds = true;
    _lastBoundsKey = boundsKey;
    setState(() => _loading = true);

    try {
      final List<ReportModel> data = await widget.repository
          .fetchReportsInBounds(
            minLatitude: minLatitude,
            maxLatitude: maxLatitude,
            minLongitude: minLongitude,
            maxLongitude: maxLongitude,
          );
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      if (!mounted) {
        return;
      }
      setState(() => _reports = data);
    } finally {
<<<<<<< HEAD
=======
      _isFetchingBounds = false;
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

<<<<<<< HEAD
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
=======
  Future<void> _reloadForVisibleBounds() async {
    try {
      final LatLngBounds bounds = _mapController.camera.visibleBounds;
      await _loadBounds(
        minLatitude: bounds.southWest.latitude,
        maxLatitude: bounds.northEast.latitude,
        minLongitude: bounds.southWest.longitude,
        maxLongitude: bounds.northEast.longitude,
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loading = false);
    }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  }

  @override
  Widget build(BuildContext context) {
    final List<ReportModel> filtered = _reports
<<<<<<< HEAD
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
=======
        .where((ReportModel report) => report.hasValidCoordinates)
        .where((ReportModel report) => _matchesFilter(report.category))
        .where((ReportModel report) => _matchesStatusFilter(report.status))
        .toList(growable: false);

    final List<Marker> markers = filtered
        .map((ReportModel report) => _buildReportMarker(report))
        .toList(growable: false);
    final List<CircleMarker> heatCircles = filtered.length > 500
        ? const <CircleMarker>[]
        : _buildHeatmapCircles(filtered);

    return Column(
      children: <Widget>[
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.all(8),
          child: Row(
<<<<<<< HEAD
            children: [
=======
            children: <Widget>[
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
            children: [
=======
            children: <Widget>[
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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
<<<<<<< HEAD
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
=======
            children: <Widget>[
              RepaintBoundary(child: _buildMap(markers, heatCircles)),
              if (!_loading && filtered.isEmpty)
                const _MapEmptyState(message: 'No reports available'),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
=======
  Widget _buildMap(List<Marker> markers, List<CircleMarker> heatCircles) {
    try {
      return FlutterMap(
        mapController: _mapController,
        options: MapOptions(
          initialCenter: _defaultCenter,
          initialZoom: 12,
          onPositionChanged: (position, hasGesture) {
            if (!hasGesture) {
              return;
            }
            _debounce?.cancel();
            _debounce = Timer(
              const Duration(milliseconds: 350),
              _reloadForVisibleBounds,
            );
          },
        ),
        children: <Widget>[
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'com.example.solapur_road_monitoring',
          ),
          if (heatCircles.isNotEmpty) CircleLayer(circles: heatCircles),
          MarkerLayer(markers: markers),
        ],
      );
    } catch (_) {
      return const _MapEmptyState(message: 'Map unavailable');
    }
  }

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
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

<<<<<<< HEAD
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
=======
  Color _markerColor(String status) {
    switch (status) {
      case 'Pending':
      case 'Reported':
        return Colors.red;
      case 'Assigned':
        return Colors.yellow.shade700;
      case 'In Progress':
        return Colors.blue;
      case 'Under Review':
        return Colors.orange;
      case 'Resolved':
      case 'Fixed':
        return Colors.green;
      default:
        return Colors.red;
    }
  }

  Marker _buildReportMarker(ReportModel report) {
    if (!report.hasValidCoordinates) {
      return Marker(
        point: _defaultCenter,
        width: 0,
        height: 0,
        child: const SizedBox.shrink(),
      );
    }

    return Marker(
      point: LatLng(report.latitude, report.longitude),
      width: 44,
      height: 44,
      child: GestureDetector(
        onTap: () => _openDetails(report),
        child: Icon(
          Icons.location_pin,
          color: _markerColor(report.status),
          size: 40,
        ),
      ),
    );
  }

  List<CircleMarker> _buildHeatmapCircles(List<ReportModel> reports) {
    final Map<String, List<ReportModel>> grouped =
        <String, List<ReportModel>>{};

    for (final ReportModel report in reports) {
      if (!report.hasValidCoordinates) {
        continue;
      }
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
      final String key =
          '${report.latitude.toStringAsFixed(3)},${report.longitude.toStringAsFixed(3)}';
      grouped.putIfAbsent(key, () => <ReportModel>[]).add(report);
    }

<<<<<<< HEAD
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
=======
    final List<CircleMarker> circles = <CircleMarker>[];
    grouped.forEach((key, group) {
      final ReportModel report = group.first;
      final int density = group.length;
      final Color color = density >= 5
          ? Colors.red.withAlpha(90)
          : density >= 3
          ? Colors.yellow.withAlpha(90)
          : Colors.green.withAlpha(90);

      circles.add(
        CircleMarker(
          point: LatLng(report.latitude, report.longitude),
          radius: 18 + (density * 3).toDouble(),
          color: color,
          borderStrokeWidth: 0,
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
        ),
      );
    });
    return circles;
  }

  void _openDetails(ReportModel report) {
<<<<<<< HEAD
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
=======
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            ReportDetailScreen(report: report, repository: widget.repository),
      ),
    );
  }
}

class _MapEmptyState extends StatelessWidget {
  const _MapEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.center,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.map_outlined,
                size: 40,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(height: 8),
              Text(message, style: Theme.of(context).textTheme.titleMedium),
            ],
          ),
        ),
      ),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    );
  }
}
