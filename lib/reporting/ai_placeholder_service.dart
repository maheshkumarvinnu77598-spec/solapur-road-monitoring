import 'dart:async';
import 'dart:io';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/ai_result.dart';

class AiPlaceholderService {
  static const String _defaultBaseUrl = 'http://192.168.0.215:8000';
  static const String _configuredBaseUrl = String.fromEnvironment(
    'AI_BASE_URL',
    defaultValue: _defaultBaseUrl,
  );
  static const String _configuredEndpoint = String.fromEnvironment(
    'AI_DETECT_URL',
  );

  String get _endpoint {
    if (_configuredEndpoint.isNotEmpty) {
      return _configuredEndpoint;
    }
    return '$_configuredBaseUrl/detect';
  }

  Future<AiResult> analyzeRoadImage({
    required File imageFile,
    required String userSelectedCategory,
  }) async {
    final String imagePath = imageFile.path;
    final bool imageExists = imageFile.existsSync();
    debugPrint('AI upload imagePath: $imagePath');
    debugPrint('AI upload imageExists: $imageExists');
    debugPrint('AI upload endpoint: $_endpoint');

    if (!imageExists) {
      debugPrint('AI upload skipped: file does not exist.');
      return AiResult(
        category: userSelectedCategory,
        severity: 'low',
        confidence: 0.5,
        boxes: const <AiBox>[],
      );
    }
    if (_endpoint.isNotEmpty) {
      try {
        final request = http.MultipartRequest('POST', Uri.parse(_endpoint));
        request.fields.remove('file');
        request.files.clear();
        request.files.add(
          await http.MultipartFile.fromPath('image', imagePath),
        );
        if (request.files.length != 1 || request.files.single.field != 'image') {
          debugPrint('AI upload corrected unexpected multipart file payload.');
          request.files
            ..clear()
            ..add(await http.MultipartFile.fromPath('image', imagePath));
        }
        final response = await request.send().timeout(
          const Duration(seconds: 30),
        );
        final String body = await response.stream.bytesToString();
        debugPrint('AI upload response status: ${response.statusCode}');
        debugPrint('AI upload response body: $body');

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final Map<String, dynamic> data =
              jsonDecode(body) as Map<String, dynamic>;
          final List<Map<String, dynamic>> detections =
              ((data['detections'] as List<dynamic>?) ?? const <dynamic>[])
                  .whereType<Map<String, dynamic>>()
                  .toList(growable: false);
          final List<AiBox> boxes = detections
              .map((Map<String, dynamic> detection) {
                final Map<String, dynamic> box =
                    detection['box'] as Map<String, dynamic>? ??
                    const <String, dynamic>{};
                return AiBox.fromMap(box);
              })
              .toList(growable: false);
          final Map<String, dynamic>? primaryDetection = detections.isNotEmpty
              ? detections.first
              : null;
          return AiResult(
            category: primaryDetection?['label'] as String? ??
                data['issue'] as String? ??
                userSelectedCategory,
            severity: data['severity'] as String? ??
                (detections.length > 1 ? 'high' : 'medium'),
            confidence:
                (primaryDetection?['confidence'] as num?)?.toDouble() ??
                (data['confidence'] as num?)?.toDouble() ??
                (detections.isNotEmpty ? 0.7 : 0.5),
            boxes: boxes,
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
        // Fall back to heuristic placeholder.
      }
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
      category: userSelectedCategory,
      severity: severity,
      confidence: confidence,
      boxes: const <AiBox>[AiBox(x: 80, y: 120, width: 120, height: 80)],
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
