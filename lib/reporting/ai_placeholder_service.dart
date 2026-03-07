import 'dart:io';
import 'dart:convert';

import 'package:http/http.dart' as http;
import '../models/ai_result.dart';

class AiPlaceholderService {
  static const String _endpoint = String.fromEnvironment('AI_DETECT_URL');

  Future<AiResult> analyzeRoadImage({
    required File imageFile,
    required String userSelectedCategory,
  }) async {
    if (!imageFile.existsSync()) {
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
        request.files.add(
          await http.MultipartFile.fromPath('image', imageFile.path),
        );
        final response = await request.send();
        if (response.statusCode >= 200 && response.statusCode < 300) {
          final String body = await response.stream.bytesToString();
          final Map<String, dynamic> data = jsonDecode(body) as Map<String, dynamic>;
          return AiResult(
            category: data['issue'] as String? ?? userSelectedCategory,
            severity: data['severity'] as String? ?? 'medium',
            confidence: (data['confidence'] as num?)?.toDouble() ?? 0.7,
            boxes: ((data['boxes'] as List<dynamic>?) ?? const <dynamic>[])
                .whereType<Map<String, dynamic>>()
                .map(AiBox.fromMap)
                .toList(growable: false),
          );
        }
      } catch (_) {
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
