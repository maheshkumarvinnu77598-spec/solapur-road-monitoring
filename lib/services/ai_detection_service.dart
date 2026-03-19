import 'dart:async';
import 'dart:io';

import '../models/ai_result.dart';
import 'flask_pothole_service.dart';

class AiDetectionService {
  AiDetectionService({
    FlaskPotholeService? flaskService,
    Duration timeout = const Duration(seconds: 8),
  }) : _flaskService = flaskService ?? FlaskPotholeService(),
       _timeout = timeout;

  final FlaskPotholeService _flaskService;
  final Duration _timeout;

  Future<AiResult> analyzeRoadImage({
    required File imageFile,
    required String fallbackCategory,
  }) async {
    if (!await imageFile.exists()) {
      return _fallback(category: fallbackCategory);
    }

    try {
      final PotholeDetectionResult response = await _flaskService
          .predictPothole(imageFile: imageFile)
          .timeout(_timeout);
      return _fromDetectionResponse(
        response,
        fallbackCategory: fallbackCategory,
      );
    } catch (_) {
      return _fallback(category: fallbackCategory, imageFile: imageFile);
    }
  }

  AiResult _fromDetectionResponse(
    PotholeDetectionResult payload, {
    required String fallbackCategory,
  }) {
    final bool isPothole = payload.isPothole;
    return AiResult(
      category: isPothole ? 'Pothole' : fallbackCategory,
      severity: payload.severity,
      confidence: payload.confidence,
      boxes: const <AiBox>[],
      detectedLabel: payload.prediction,
    );
  }

  Future<AiResult> _fallback({
    required String category,
    File? imageFile,
  }) async {
    if (imageFile == null) {
      return AiResult(
        category: category,
        severity: 'low',
        confidence: 0.5,
        boxes: const <AiBox>[],
        detectedLabel: 'unknown',
        isFallback: true,
      );
    }

    final int bytes = await imageFile.length();
    final double sizeMb = bytes / (1024 * 1024);
    final String severity = sizeMb > 1.4
        ? 'high'
        : sizeMb > 0.9
        ? 'medium'
        : 'low';
    final double confidence = sizeMb > 1.2 ? 0.87 : 0.72;

    return AiResult(
      category: category,
      severity: severity,
      confidence: confidence,
      boxes: const <AiBox>[AiBox(x: 80, y: 120, width: 120, height: 80)],
      detectedLabel: 'unknown',
      isFallback: true,
    );
  }
}
