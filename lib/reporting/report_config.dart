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
  IssueCategory('Water Logging', Icons.flood_rounded),
  IssueCategory('Open Manhole', Icons.dangerous_rounded),
  IssueCategory('Garbage Dumping', Icons.delete_outline_rounded),
  IssueCategory('Street Light Not Working', Icons.lightbulb_outline_rounded),
];

String priorityForCategory(String category) {
  switch (category) {
    case 'Open Manhole':
      return 'critical';
    case 'Pothole':
    case 'Water Logging':
      return 'high';
    case 'Garbage Dumping':
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
  'Under Review',
  'Fixed',
];
