class AiBox {
  const AiBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'x': x,
      'y': y,
      'width': width,
      'height': height,
    };
  }

  factory AiBox.fromMap(Map<String, dynamic> map) {
    return AiBox(
      x: (map['x'] as num?)?.toDouble() ?? 0,
      y: (map['y'] as num?)?.toDouble() ?? 0,
      width: (map['width'] as num?)?.toDouble() ?? 0,
      height: (map['height'] as num?)?.toDouble() ?? 0,
    );
  }
}

class AiResult {
  const AiResult({
    required this.category,
    required this.severity,
    required this.confidence,
    required this.boxes,
    this.detectedLabel,
    this.isFallback = false,
  });

  final String category;
  final String severity;
  final double confidence;
  final List<AiBox> boxes;
  final String? detectedLabel;
  final bool isFallback;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'category': category,
      'severity': severity,
      'confidence': confidence,
      'boxes': boxes.map((AiBox box) => box.toMap()).toList(growable: false),
      'detectedLabel': detectedLabel,
      'isFallback': isFallback,
    };
  }

  factory AiResult.fromMap(Map<String, dynamic> map) {
    final List<dynamic> rawBoxes = map['boxes'] as List<dynamic>? ?? <dynamic>[];
    return AiResult(
      category: map['category'] as String? ?? 'unknown',
      severity: map['severity'] as String? ?? 'low',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      boxes: rawBoxes
          .whereType<Map<String, dynamic>>()
          .map(AiBox.fromMap)
          .toList(growable: false),
      detectedLabel: map['detectedLabel'] as String?,
      isFallback: map['isFallback'] as bool? ?? false,
    );
  }
}
