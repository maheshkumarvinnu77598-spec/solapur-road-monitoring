import 'package:flutter/material.dart';

import '../ui_theme/app_theme.dart';

class IssueCategory {
  const IssueCategory(this.name, this.icon);

  final String name;
  final IconData icon;
}

const List<IssueCategory> issueCategories = <IssueCategory>[
  IssueCategory('Pothole', Icons.warning_amber_rounded),
  IssueCategory('Road Surface Damage', Icons.construction_rounded),
  IssueCategory('Incomplete Road Work', Icons.engineering_rounded),
  IssueCategory('Damaged Footpath', Icons.directions_walk_rounded),
  IssueCategory('Water Logging / Flooded Street', Icons.flood_rounded),
  IssueCategory('Open Manhole / Drain Cover Damage', Icons.dangerous_rounded),
  IssueCategory(
    'Garbage Dumping / Waste Overflow',
    Icons.delete_outline_rounded,
  ),
  IssueCategory('Street Light Not Working', Icons.lightbulb_outline_rounded),
];

String priorityForCategory(String category) {
  switch (category) {
    case 'Open Manhole / Drain Cover Damage':
      return 'critical';
    case 'Pothole':
    case 'Water Logging / Flooded Street':
      return 'high';
    case 'Garbage Dumping / Waste Overflow':
    case 'Street Light Not Working':
      return 'medium';
    default:
      return 'low';
  }
}

Color colorForPriority(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return AppPalette.critical;
    case 'high':
      return AppPalette.high;
    case 'medium':
      return AppPalette.medium;
    default:
      return AppPalette.low;
  }
}

const List<String> reportStatuses = <String>[
  'Reported',
  'Assigned',
  'In Progress',
  'Resolved',
];
