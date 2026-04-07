import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/ai_result.dart';
import 'report_config.dart';

class AiPlaceholderService {
  static const String _defaultBaseUrl = 'http://127.0.0.1:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  static const String _configuredEndpoint = String.fromEnvironment(
    'AI_DETECT_URL',
  );

  List<String> get _candidateEndpoints {
    final List<String> endpoints = <String>[];
    if (_configuredEndpoint.isNotEmpty) {
      endpoints.add(_configuredEndpoint);
    }
    endpoints.add('$_configuredBaseUrl/detect');
    if (_configuredBaseUrl != 'http://127.0.0.1:8000') {
      endpoints.add('http://127.0.0.1:8000/detect');
    }
    if (!kIsWeb) {
      endpoints.add('http://10.0.2.2:8000/detect');
    }
    return endpoints.toSet().toList(growable: false);
  }

  Future<AiResult> analyzeRoadImage({
    required File imageFile,
    required String userSelectedCategory,
  }) async {
    final String imagePath = imageFile.path;
    final bool imageExists = imageFile.existsSync();
    debugPrint('AI upload imagePath: $imagePath');
    debugPrint('AI upload imageExists: $imageExists');

    if (!imageExists) {
      debugPrint('AI upload skipped: file does not exist.');
      return _fallback(category: userSelectedCategory);
    }

    for (final String endpoint in _candidateEndpoints) {
      debugPrint('AI upload endpoint: $endpoint');
      try {
        final http.MultipartRequest request = http.MultipartRequest(
          'POST',
          Uri.parse(endpoint),
        );
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );

        final http.StreamedResponse response = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final String body = await response.stream.bytesToString();
        debugPrint('AI upload response status: ${response.statusCode}');
        debugPrint('AI upload response body: $body');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data =
              jsonDecode(body) as Map<String, dynamic>;
          return _fromBackendPayload(
            data,
            userSelectedCategory: userSelectedCategory,
          );
        }

        debugPrint('AI upload HTTP error: ${response.statusCode}');
      } on http.ClientException catch (error) {
        debugPrint('AI upload client error: $error');
      } on SocketException catch (error) {
        debugPrint('AI upload network error: $error');
      } on HttpException catch (error) {
        debugPrint('AI upload HTTP exception: $error');
      } on FormatException catch (error) {
        debugPrint('AI upload parse error: $error');
      } on TimeoutException catch (error) {
        debugPrint('AI upload timeout: $error');
      } catch (error) {
        debugPrint('AI upload unexpected error: $error');
      }
    }

    return _fallback(category: userSelectedCategory, imageFile: imageFile);
  }

  AiResult _fromBackendPayload(
    Map<String, dynamic> data, {
    required String userSelectedCategory,
  }) {
    final List<AiBox> boxes = ((data['boxes'] as List<dynamic>?) ?? <dynamic>[])
        .whereType<Map<String, dynamic>>()
        .map(AiBox.fromMap)
        .toList(growable: false);

    final String detectedIssue = (data['issue'] as String? ?? '').trim();
    final String category = resolveCategory(
      detectedIssue,
      fallbackCategory: userSelectedCategory,
    );

    return AiResult(
      category: category,
      severity: (data['severity'] as String? ?? 'low').toLowerCase(),
      confidence: (data['confidence'] as num?)?.toDouble() ?? 0,
      boxes: boxes,
      detectedLabel: detectedIssue.isEmpty ? null : detectedIssue,
      isFallback: false,
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
        detectedLabel: null,
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
    final double confidence = sizeMb > 1.2 ? 0.72 : 0.55;

    return AiResult(
      category: category,
      severity: severity,
      confidence: confidence,
      boxes: const <AiBox>[],
      detectedLabel: null,
      isFallback: true,
    );
  }
}

Future<AiResult> analyzeRoadImage(
  File imageFile, {
  required String userSelectedCategory,
}) {
  return AiPlaceholderService().analyzeRoadImage(
    imageFile: imageFile,
    userSelectedCategory: userSelectedCategory,
  );
}
