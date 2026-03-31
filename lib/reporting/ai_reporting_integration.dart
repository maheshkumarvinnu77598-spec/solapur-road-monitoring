// AI-powered report wizard integration module.
// Handles Flask pothole detection in the reporting flow.

import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';

import '../services/flask_pothole_service.dart';
import '../ui_theme/ai_result_card.dart';

/// Configuration for AI integration
class AiIntegrationConfig {
  /// Enable AI pothole detection
  final bool enabled;

  /// Flask API base URL (if null, uses device detection)
  final String? flaskBaseUrl;

  /// Auto-select "Pothole" category when detected
  final bool autoSelectPotholeCategory;

  /// Set priority to "High" for detected potholes
  final bool autoSetHighPriority;

  /// Show AI result card UI
  final bool showResultCard;

  /// Timeout for API requests (seconds)
  final int timeoutSeconds;

  const AiIntegrationConfig({
    this.enabled = true,
    this.flaskBaseUrl,
    this.autoSelectPotholeCategory = true,
    this.autoSetHighPriority = true,
    this.showResultCard = true,
    this.timeoutSeconds = 30,
  });

  /// Copy with modifications
  AiIntegrationConfig copyWith({
    bool? enabled,
    String? flaskBaseUrl,
    bool? autoSelectPotholeCategory,
    bool? autoSetHighPriority,
    bool? showResultCard,
    int? timeoutSeconds,
  }) {
    return AiIntegrationConfig(
      enabled: enabled ?? this.enabled,
      flaskBaseUrl: flaskBaseUrl ?? this.flaskBaseUrl,
      autoSelectPotholeCategory:
          autoSelectPotholeCategory ?? this.autoSelectPotholeCategory,
      autoSetHighPriority: autoSetHighPriority ?? this.autoSetHighPriority,
      showResultCard: showResultCard ?? this.showResultCard,
      timeoutSeconds: timeoutSeconds ?? this.timeoutSeconds,
    );
  }
}

/// Result of AI analysis with enhanced metadata
class EnhancedAiResult {
  final PotholeDetectionResult detection;
  final DateTime analyzedAt;
  final String imagePath;
  final bool? isRetry;

  EnhancedAiResult({
    required this.detection,
    required this.imagePath,
    this.isRetry = false,
    DateTime? analyzedAt,
  }) : analyzedAt = analyzedAt ?? DateTime.now();

  /// Suggested category based on detection
  String get suggestedCategory =>
      detection.isPothole ? 'Pothole' : 'Road Damage';

  /// Suggested priority based on detection and confidence
  String get suggestedPriority {
    if (!detection.isPothole) return 'Low';
    if (detection.confidence >= 0.85) return 'Critical';
    if (detection.confidence >= 0.75) return 'High';
    return 'Medium';
  }

  /// Whether to auto-apply suggestions
  bool get shouldAutoApply =>
      detection.isPothole && detection.confidence >= 0.7;
}

/// Manager for AI integration in reporting flow
class AiReportingIntegration {
  final FlaskPotholeService _service = FlaskPotholeService();
  final AiIntegrationConfig config;

  AiReportingIntegration({AiIntegrationConfig? config})
    : config = config ?? const AiIntegrationConfig();

  /// Initialize Flask service with custom URL if provided
  void initialize() {
    if (config.flaskBaseUrl != null) {
      _service.setBaseUrl(config.flaskBaseUrl!);
    }
  }

  /// Analyze image for pothole detection
  Future<EnhancedAiResult?> analyzeImage({
    required File imageFile,
    VoidCallback? onAnalyzing,
  }) async {
    if (!config.enabled) return null;

    try {
      onAnalyzing?.call();

      final PotholeDetectionResult result = await _service
          .predictPothole(imageFile: imageFile)
          .timeout(
            Duration(seconds: config.timeoutSeconds),
            onTimeout: () {
              throw TimeoutException('Analysis timeout');
            },
          );

      return EnhancedAiResult(detection: result, imagePath: imageFile.path);
    } catch (e) {
      return null;
    }
  }

  /// Get UI widget for result display
  Widget buildResultWidget(EnhancedAiResult result, {VoidCallback? onDismiss}) {
    if (!config.showResultCard) return const SizedBox.shrink();

    return AiPotholeResultCard(result: result.detection, onDismiss: onDismiss);
  }

  /// Get loading widget
  Widget buildLoadingWidget() {
    return const AiLoadingCard();
  }

  /// Get error widget
  Widget buildErrorWidget({
    String message =
        'AI analysis unavailable. Continue manually with confidence.',
    VoidCallback? onRetry,
  }) {
    return AiErrorCard(message: message, onRetry: onRetry);
  }

  /// Build complete result section
  /// Returns null if no analysis or result
  Widget? buildResultSection(
    EnhancedAiResult? result, {
    bool isAnalyzing = false,
    bool isError = false,
    String? errorMessage,
    VoidCallback? onRetry,
  }) {
    if (isAnalyzing) {
      return buildLoadingWidget();
    }

    if (isError) {
      return buildErrorWidget(
        message:
            errorMessage ??
            'AI analysis failed. You can continue without AI results.',
        onRetry: onRetry,
      );
    }

    if (result != null) {
      return buildResultWidget(result);
    }

    return null;
  }

  /// Test API connectivity
  Future<bool> testConnection() => _service.testConnection();
}

/// UI State manager for AI analysis during report wizard
class AiAnalysisState {
  PotholeDetectionResult? result;
  bool isAnalyzing = false;
  bool hasError = false;
  String? errorMessage;
  DateTime? analyzedAt;

  /// Reset to initial state
  void reset() {
    result = null;
    isAnalyzing = false;
    hasError = false;
    errorMessage = null;
    analyzedAt = null;
  }

  /// Mark as analyzing
  void startAnalyzing() {
    isAnalyzing = true;
    hasError = false;
    errorMessage = null;
    result = null;
  }

  /// Mark analysis complete
  void completeAnalysis(PotholeDetectionResult detectionResult) {
    result = detectionResult;
    isAnalyzing = false;
    hasError = false;
    errorMessage = null;
    analyzedAt = DateTime.now();
  }

  /// Mark analysis failed
  void failAnalysis(String message) {
    isAnalyzing = false;
    hasError = true;
    errorMessage = message;
    result = null;
  }

  /// Copy state
  AiAnalysisState copy() {
    return AiAnalysisState()
      ..result = result
      ..isAnalyzing = isAnalyzing
      ..hasError = hasError
      ..errorMessage = errorMessage
      ..analyzedAt = analyzedAt;
  }
}
