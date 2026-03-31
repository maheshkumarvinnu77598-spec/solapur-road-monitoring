import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class DemoNetworkImage extends StatelessWidget {
  const DemoNetworkImage({
    super.key,
    required this.imageUrl,
    required this.height,
    this.width = double.infinity,
    this.fit = BoxFit.cover,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
  });

  final String imageUrl;
  final double height;
  final double width;
  final BoxFit fit;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    final Color placeholder = Theme.of(
      context,
    ).colorScheme.surfaceContainerHighest;

    if (imageUrl.isEmpty) {
      return _fallback(placeholder);
    }

    return ClipRRect(
      borderRadius: borderRadius,
      child: Image.network(
        imageUrl,
        height: height,
        width: width,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => _fallback(placeholder),
        loadingBuilder: (context, child, progress) {
          if (progress == null) {
            return child;
          }
          return Container(
            height: height,
            width: width,
            color: placeholder,
            alignment: Alignment.center,
            child: const CircularProgressIndicator(strokeWidth: 2),
          );
        },
      ),
    );
  }

  Widget _fallback(Color placeholder) {
    return Container(
      height: height,
      width: width,
      color: placeholder,
      alignment: Alignment.center,
      child: const Icon(Icons.broken_image_outlined),
    );
  }
}

class DemoMapPreview extends StatelessWidget {
  const DemoMapPreview({
    super.key,
    required this.latitude,
    required this.longitude,
    required this.height,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.zoom = 15,
  });

  final double latitude;
  final double longitude;
  final double height;
  final BorderRadius borderRadius;
  final double zoom;

  @override
  Widget build(BuildContext context) {
    try {
      return ClipRRect(
        borderRadius: borderRadius,
        child: SizedBox(
          height: height,
          child: FlutterMap(
            options: MapOptions(
              initialCenter: LatLng(latitude, longitude),
              initialZoom: zoom,
            ),
            children: <Widget>[
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.solapur_road_monitoring',
              ),
              MarkerLayer(
                markers: <Marker>[
                  Marker(
                    point: LatLng(latitude, longitude),
                    child: const Icon(
                      Icons.location_on,
                      color: Colors.red,
                      size: 40,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    } catch (_) {
      return _fallback(context);
    }
  }

  Widget _fallback(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: borderRadius,
      ),
      alignment: Alignment.center,
      child: const Text('Map unavailable'),
    );
  }
}

class DemoEmptyState extends StatelessWidget {
  const DemoEmptyState({super.key, required this.message, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              icon ?? Icons.inbox_outlined,
              size: 36,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
