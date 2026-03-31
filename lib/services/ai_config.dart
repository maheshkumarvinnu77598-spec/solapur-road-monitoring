// ignore_for_file: constant_identifier_names, non_constant_identifier_names

// Environment and configuration for AI Pothole Detection Service.
// This file contains all configurable parameters for Flask AI integration.
// Modify values here to suit your deployment environment.

import 'package:flutter/foundation.dart';

/// Application environment
enum AppEnvironment { development, staging, production }

/// AI Service Configuration
/// Centralized configuration for Flask pothole detection API
class AiServiceConfig {
  // ========== Flask API Configuration ==========

  /// Flask API base URL for Android Emulator
  /// Emulator routes http://10.0.2.2 to host machine localhost
  static const String FLASK_EMULATOR_URL = 'http://10.0.2.2:5000';

  /// Flask API base URL for physical Android device
  /// Replace 192.168.x.x with your development machine IP
  /// You can also use ngrok or other tunneling services
  static const String FLASK_DEVICE_URL = 'http://localhost:5000';

  /// Flask API base URL for iOS (simulator or device)
  static const String FLASK_IOS_URL = 'http://localhost:5000';

  /// Flask API endpoint path
  static const String FLASK_PREDICT_ENDPOINT = '/predict';

  /// Flask API endpoint for health check
  static const String FLASK_HEALTH_ENDPOINT = '/health';

  // ========== Request/Response Configuration ==========

  /// HTTP request timeout (seconds)
  static const int REQUEST_TIMEOUT_SECONDS = 30;

  /// Maximum image size before compression (MB)
  static const int MAX_IMAGE_SIZE_MB = 5;

  /// Image quality for compression (0-100)
  static const int IMAGE_COMPRESSION_QUALITY = 75;

  /// Minimum confidence threshold for auto-accepting predictions
  /// Range: 0.0 to 1.0
  static const double AUTO_ACCEPT_CONFIDENCE_THRESHOLD = 0.70;

  // ========== AI Behavior Configuration ==========

  /// Enable AI pothole detection feature
  static const bool ENABLE_AI_DETECTION = true;

  /// Auto-select "Pothole" category when detected
  /// Set false if you want user to manually confirm
  static const bool AUTO_SELECT_POTHOLE_CATEGORY = true;

  /// Auto-set priority to "High" for detected potholes
  static const bool AUTO_SET_HIGH_PRIORITY = true;

  /// Show AI result card in UI
  /// Set false to disable UI but keep AI processing in background
  static const bool SHOW_AI_RESULT_CARD = true;

  /// Require AI analysis before allowing report submission
  /// Set true to force AI validation. Set false for optional AI.
  static const bool REQUIRE_AI_ANALYSIS = false;

  // ========== Logging & Analytics ==========

  /// Enable detailed AI service logging
  static const bool DEBUG_LOGGING = kDebugMode;

  /// Log all AI predictions to analytics
  static const bool LOG_PREDICTIONS = true;

  /// Log API response times
  static const bool LOG_PERFORMANCE = true;

  // ========== Prediction Model Configuration ==========

  /// Prediction types the model can return
  static const List<String> VALID_PREDICTIONS = ['pothole', 'normal'];

  /// Confidence adjustment factor (for model calibration)
  /// Multiply all confidence scores by this value
  /// Useful if model is over/under confident
  static const double CONFIDENCE_MULTIPLIER = 1.0;

  /// Category mapping for AI predictions
  /// Maps AI prediction to app category
  static const Map<String, String> PREDICTION_TO_CATEGORY = {
    'pothole': 'Pothole',
    'normal': 'Road Damage',
  };

  /// Priority mapping based on confidence
  /// Confidence threshold: priority
  static final Map<double, String> CONFIDENCE_TO_PRIORITY = {
    0.0: 'Low',
    0.5: 'Medium',
    0.75: 'High',
    0.85: 'Critical',
  };

  // ========== Error Handling ==========

  /// Allow app to continue without AI if API fails
  /// Set false to block reporting if AI unavailable
  static const bool ALLOW_FALLBACK_ON_ERROR = true;

  /// Retry failed AI requests
  static const int MAX_RETRIES = 2;

  /// Delay between retries (milliseconds)
  static const int RETRY_DELAY_MS = 1000;

  // ========== Device Detection ==========

  /// Auto-detect device type (emulator vs device)
  /// If true, uses 10.0.2.2 for emulator, localhost for device
  static const bool AUTO_DETECT_DEVICE = true;

  // ========== Feature Flags ==========

  /// Enable AI model ensemble (multiple models)
  /// For future: run multiple models and average results
  static const bool ENABLE_MODEL_ENSEMBLE = false;

  /// Enable model versioning/selection
  /// For future: switch between different model versions
  static const bool ENABLE_MODEL_VERSIONING = false;

  /// Enable confidence calibration
  /// For future: adjust confidence scores based on historical accuracy
  static const bool ENABLE_CONFIDENCE_CALIBRATION = false;

  // ========== Current Environment ==========

  /// Current app environment
  static const AppEnvironment APP_ENVIRONMENT = AppEnvironment.development;

  /// Get Flask URL for current environment and platform
  static String getFlaskBaseUrl() {
    // Platform-specific detection could be added here
    // For now, emulator detection happens in FlaskPotholeService
    return FLASK_EMULATOR_URL;
  }

  // ========== Helper Methods ==========

  /// Get priority for a given confidence level
  static String getPriorityForConfidence(double confidence) {
    final List<MapEntry<double, String>> entries = CONFIDENCE_TO_PRIORITY
        .entries
        .toList();
    entries.sort((a, b) => b.key.compareTo(a.key));

    for (final entry in entries) {
      if (confidence >= entry.key) {
        return entry.value;
      }
    }
    return 'Low';
  }

  /// Validate prediction value
  static bool isValidPrediction(String prediction) {
    return VALID_PREDICTIONS.contains(prediction.toLowerCase());
  }

  /// Validate confidence value
  static bool isValidConfidence(double confidence) {
    return confidence >= 0.0 && confidence <= 1.0;
  }

  /// Get adjusted confidence with multiplier
  static double getAdjustedConfidence(double rawConfidence) {
    return (rawConfidence * CONFIDENCE_MULTIPLIER).clamp(0.0, 1.0);
  }

  /// Should auto-accept this prediction?
  static bool shouldAutoAccept(double confidence) {
    return confidence >= AUTO_ACCEPT_CONFIDENCE_THRESHOLD;
  }

  // ========== Configuration Presets ==========

  /// Get config preset for testing without Flask
  static Map<String, dynamic> getTestingPreset() {
    return {
      'ENABLE_AI_DETECTION': false,
      'ALLOW_FALLBACK_ON_ERROR': true,
      'DEBUG_LOGGING': true,
    };
  }

  /// Get config preset for hackathon demo
  /// (aggressive AI application for demo)
  static Map<String, dynamic> getHackathonDemoPreset() {
    return {
      'ENABLE_AI_DETECTION': true,
      'AUTO_SELECT_POTHOLE_CATEGORY': true,
      'AUTO_SET_HIGH_PRIORITY': true,
      'SHOW_AI_RESULT_CARD': true,
      'AUTO_ACCEPT_CONFIDENCE_THRESHOLD': 0.60,
      'REQUIRE_AI_ANALYSIS': false,
      'ALLOW_FALLBACK_ON_ERROR': true,
      'DEBUG_LOGGING': true,
    };
  }

  /// Get config preset for production
  /// (conservative, reliability-focused)
  static Map<String, dynamic> getProductionPreset() {
    return {
      'ENABLE_AI_DETECTION': true,
      'AUTO_SELECT_POTHOLE_CATEGORY': false,
      'AUTO_SET_HIGH_PRIORITY': false,
      'SHOW_AI_RESULT_CARD': true,
      'AUTO_ACCEPT_CONFIDENCE_THRESHOLD': 0.85,
      'REQUIRE_AI_ANALYSIS': false,
      'ALLOW_FALLBACK_ON_ERROR': true,
      'DEBUG_LOGGING': false,
      'LOG_PREDICTIONS': true,
      'LOG_PERFORMANCE': true,
    };
  }

  /// Get config preset optimized for performance
  static Map<String, dynamic> getPerformanceOptimizedPreset() {
    return {
      'REQUEST_TIMEOUT_SECONDS': 15,
      'IMAGE_COMPRESSION_QUALITY': 60,
      'MAX_RETRIES': 1,
      'ENABLE_MODEL_ENSEMBLE': false,
      'DEBUG_LOGGING': false,
    };
  }
}

/// Example: How to use configuration in your code
/// 
/// ```dart
/// import 'services/ai_config.dart';
/// 
/// // Get Flask URL
/// final String flaskUrl = AiServiceConfig.getFlaskBaseUrl();
/// 
/// // Check if should auto-accept
/// if (AiServiceConfig.shouldAutoAccept(confidenceScore)) {
///   // Auto-select category
/// }
/// 
/// // Validate prediction
/// if (AiServiceConfig.isValidPrediction(prediction)) {
///   // Process prediction
/// }
/// 
/// // Apply hackathon demo preset
/// // (In real app, merge with default config)
/// final hackathonConfig = AiServiceConfig.getHackathonDemoPreset();
/// ```
