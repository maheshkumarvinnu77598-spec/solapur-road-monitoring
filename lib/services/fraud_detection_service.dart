import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;

class FraudCheckResult {
  const FraudCheckResult({
    required this.passed,
    required this.reason,
    required this.brightness,
    required this.sharpness,
  });

  final bool passed;
  final String reason;
  final double brightness;
  final double sharpness;
}

class FraudDetectionService {
  static const double _minBrightness = 28;
  static const double _minSharpness = 7;

  Future<FraudCheckResult> validateImage(File file) async {
    if (!await file.exists()) {
      return const FraudCheckResult(
        passed: false,
        reason: 'Image file not found.',
        brightness: 0,
        sharpness: 0,
      );
    }

    final Uint8List bytes = await file.readAsBytes();
    final _ImageMetrics metrics = await compute(_measureMetrics, bytes);

    if (metrics.brightness < _minBrightness) {
      return FraudCheckResult(
        passed: false,
        reason: 'Image is too dark. Please capture in better light.',
        brightness: metrics.brightness,
        sharpness: metrics.sharpness,
      );
    }

    if (metrics.sharpness < _minSharpness) {
      return FraudCheckResult(
        passed: false,
        reason: 'Image appears blurry. Please recapture clearly.',
        brightness: metrics.brightness,
        sharpness: metrics.sharpness,
      );
    }

    return FraudCheckResult(
      passed: true,
      reason: 'OK',
      brightness: metrics.brightness,
      sharpness: metrics.sharpness,
    );
  }
}

class _ImageMetrics {
  const _ImageMetrics({required this.brightness, required this.sharpness});

  final double brightness;
  final double sharpness;
}

_ImageMetrics _measureMetrics(Uint8List bytes) {
  final img.Image? decoded = img.decodeImage(bytes);
  if (decoded == null) {
    return const _ImageMetrics(brightness: 0, sharpness: 0);
  }

  final img.Image gray = img.grayscale(decoded);
  final int width = gray.width;
  final int height = gray.height;
  if (width < 3 || height < 3) {
    return const _ImageMetrics(brightness: 0, sharpness: 0);
  }

  double sumLuma = 0;
  double edgeSum = 0;
  int edgeCount = 0;

  for (int y = 1; y < height - 1; y++) {
    for (int x = 1; x < width - 1; x++) {
      final int c = gray.getPixel(x, y).r.toInt();
      final int left = gray.getPixel(x - 1, y).r.toInt();
      final int right = gray.getPixel(x + 1, y).r.toInt();
      final int top = gray.getPixel(x, y - 1).r.toInt();
      final int bottom = gray.getPixel(x, y + 1).r.toInt();

      sumLuma += c;
      final int laplacian = (4 * c - left - right - top - bottom).abs();
      edgeSum += laplacian;
      edgeCount++;
    }
  }

  final double brightness = sumLuma / edgeCount;
  final double sharpness = edgeSum / edgeCount;

  return _ImageMetrics(brightness: brightness, sharpness: sharpness);
}
