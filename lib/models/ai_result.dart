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
    return <String, dynamic>{'x': x, 'y': y, 'width': width, 'height': height};
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
  });

  final String category;
  final String severity;
  final double confidence;
  final List<AiBox> boxes;

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'category': category,
      'severity': severity,
      'confidence': confidence,
      'boxes': boxes.map((AiBox b) => b.toMap()).toList(growable: false),
    };
  }

  factory AiResult.fromMap(Map<String, dynamic> map) {
    final List<dynamic> boxList = map['boxes'] as List<dynamic>? ?? <dynamic>[];
    return AiResult(
      category: map['category'] as String? ?? 'unknown',
      severity: map['severity'] as String? ?? 'low',
      confidence: (map['confidence'] as num?)?.toDouble() ?? 0,
      boxes: boxList
          .whereType<Map<String, dynamic>>()
          .map(AiBox.fromMap)
          .toList(growable: false),
    );
  }
}
