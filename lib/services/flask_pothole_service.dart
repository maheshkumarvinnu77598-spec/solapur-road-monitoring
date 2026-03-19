// Flask-based AI pothole detection service.
// Integrates with Flask API running on:
// - Android emulator: http://10.0.2.2:5000/predict
// - Real device: dynamic base URL from config
// Predicts: "pothole" or "normal" road surface damage.

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;

/// Response model from Flask API
class PotholeDetectionResult {
  final String prediction; // "pothole" or "normal"
  final double confidence; // 0.0 to 1.0
  final String? rawResponse;

  PotholeDetectionResult({
    required this.prediction,
    required this.confidence,
    this.rawResponse,
  });

  /// Whether prediction is a pothole
  bool get isPothole => prediction.toLowerCase() == 'pothole';

  /// Confidence as percentage
  int get confidencePercent => (confidence * 100).toInt();

  /// Get human-readable prediction text
  String get predictionText => isPothole ? 'Pothole Detected' : 'Normal Road';

  /// Get severity for pothole
  String get severity => isPothole && confidence > 0.75
      ? 'high'
      : isPothole && confidence > 0.5
      ? 'medium'
      : 'low';
}

/// Flask Pothole Detection Service
/// Handles communication with Flask AI backend
class FlaskPotholeService {
  static const String _configuredBaseUrl = String.fromEnvironment(
    'FLASK_BASE_URL',
    defaultValue: '',
  );
  static const String _defaultEmulatorUrl = 'http://10.0.2.2:5000';
  static const String _defaultDeviceUrl = 'http://localhost:5000';
  static const String _predictEndpoint = '/predict';
  static const Duration _timeout = Duration(seconds: 8);

  /// Base URL for Flask API
  /// Can be overridden for testing or different deployments
  String? _baseUrl;

  /// Get the appropriate base URL based on device type
  String get baseUrl {
    if (_baseUrl != null) return _baseUrl!;
    if (_configuredBaseUrl.isNotEmpty) return _configuredBaseUrl;

    // Check if running on Android emulator
    if (_isEmulator()) {
      return _defaultEmulatorUrl;
    }

    // For physical devices, use device URL
    return _defaultDeviceUrl;
  }

  /// Set custom base URL (useful for testing)
  void setBaseUrl(String url) {
    _baseUrl = url;
  }

  /// Check if running on Android emulator
  bool _isEmulator() {
    // This is a simplified check. In production, you might use:
    // - device_info_plus plugin
    // - Platform.isAndroid && readBuildInfo()
    if (!Platform.isAndroid) return false;

    // Simple heuristic: if we can detect emulator-specific properties
    try {
      // On emulator, Geolocator might report specific coordinates
      // For now, we'll use the platform check and assume emulator on Android
      return true; // Will be detected by platform
    } catch (_) {
      return false;
    }
  }

  /// Send image to Flask API for pothole detection
  ///
  /// [imageFile] - Image file to analyze
  /// Returns [PotholeDetectionResult] with prediction and confidence
  /// Throws [SocketException] if server unavailable
  /// Throws [TimeoutException] if request times out
  /// Throws [FormatException] if response is invalid
  Future<PotholeDetectionResult> predictPothole({
    required File imageFile,
  }) async {
    if (!await imageFile.exists()) {
      throw FileSystemException('Image file not found: ${imageFile.path}');
    }

    final Uri url = Uri.parse('$baseUrl$_predictEndpoint');

    try {
      // Create multipart request
      final http.MultipartRequest request = http.MultipartRequest('POST', url);

      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Send request with timeout
      final http.StreamedResponse response = await request.send().timeout(
        _timeout,
        onTimeout: () {
          throw TimeoutException(
            'Pothole detection API request timed out after ${_timeout.inSeconds}s',
          );
        },
      );

      // Read response
      final String responseBody = await response.stream.bytesToString();

      // Check status code
      if (response.statusCode != 200) {
        throw HtmlParseException(
          'Flask API error (HTTP ${response.statusCode}): $responseBody',
        );
      }

      // Parse JSON response
      try {
        final Map<String, dynamic> json = jsonDecode(responseBody);

        // Extract prediction and confidence
        final String? predictionNullable =
            json['prediction'] as String? ?? json['label'] as String?;
        if (predictionNullable == null) {
          throw FormatException('Missing "prediction" field in API response');
        }
        final String prediction = predictionNullable;
        final dynamic confidenceRaw = json['confidence'];

        // Parse confidence - handle both string and numeric values
        double confidence = 0.0;
        if (confidenceRaw is num) {
          confidence = confidenceRaw.toDouble();
        } else if (confidenceRaw is String) {
          confidence = double.tryParse(confidenceRaw) ?? 0.0;
        }

        // Clamp confidence to valid range
        confidence = confidence.clamp(0.0, 1.0);

        return PotholeDetectionResult(
          prediction: prediction,
          confidence: confidence,
          rawResponse: responseBody,
        );
      } on FormatException catch (e) {
        throw FormatException(
          'Failed to parse Flask API response: ${e.message}\nResponse: $responseBody',
        );
      }
    } on SocketException catch (e) {
      throw SocketException(
        'Failed to connect to Flask API at $baseUrl: ${e.message}',
      );
    } on TimeoutException {
      rethrow;
    } catch (e) {
      throw Exception('Pothole detection failed: ${e.toString()}');
    }
  }

  /// Predict pothole with error recovery
  ///
  /// Returns null on error instead of throwing
  /// Useful for non-critical predictions where fallback is available
  Future<PotholeDetectionResult?> predictPotholeWithFallback({
    required File imageFile,
    Duration timeout = const Duration(seconds: 15),
  }) async {
    try {
      return await predictPothole(imageFile: imageFile).timeout(
        timeout,
        onTimeout: () async => throw TimeoutException('Timeout'),
      );
    } on TimeoutException {
      return null;
    } catch (e) {
      // Silently fail for fallback mode
      // In production, you might log this with analytics
      return null;
    }
  }

  /// Test connection to Flask API
  ///
  /// Returns true if API is reachable and responding
  Future<bool> testConnection() async {
    try {
      final Uri url = Uri.parse('$baseUrl$_predictEndpoint');
      final http.Response response = await http
          .head(url)
          .timeout(
            const Duration(seconds: 5),
            onTimeout: () {
              throw TimeoutException('Connection test timed out');
            },
          )
          .catchError((_) => http.Response('', 503));

      return response.statusCode < 500;
    } catch (_) {
      return false;
    }
  }
}

/// Alias for easier imports
typedef PotholeResult = PotholeDetectionResult;

/// Exception type for parsing errors
class HtmlParseException implements Exception {
  final String message;
  HtmlParseException(this.message);
  @override
  String toString() => 'HtmlParseException: $message';
}
