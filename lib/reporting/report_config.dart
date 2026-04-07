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
  IssueCategory('Road Obstruction', Icons.block_rounded),
  IssueCategory('Water Logging', Icons.flood_rounded),
  IssueCategory('Drainage Blockage', Icons.water_damage_outlined),
  IssueCategory('Street Light Not Working', Icons.lightbulb_outline_rounded),
  IssueCategory('Incomplete Road Work', Icons.engineering_rounded),
  IssueCategory('Damaged Footpath', Icons.directions_walk_rounded),
  IssueCategory('Open Manhole', Icons.dangerous_rounded),
  IssueCategory('Garbage Dumping', Icons.delete_outline_rounded),
];

const Map<String, String> yoloLabelToCategory = <String, String>{
  'pothole': 'Pothole',
  'road damage': 'Road Surface Damage',
  'road_damage': 'Road Surface Damage',
  'road surface damage': 'Road Surface Damage',
  'water logging': 'Water Logging',
  'water_logging': 'Water Logging',
  'broken streetlight': 'Street Light Not Working',
  'broken street light': 'Street Light Not Working',
  'street light issue': 'Street Light Not Working',
  'street light not working': 'Street Light Not Working',
  'road obstruction': 'Road Obstruction',
  'drainage blockage': 'Drainage Blockage',
};

String resolveCategory(String? rawLabel, {String? fallbackCategory}) {
  final String normalized = (rawLabel ?? '').trim().toLowerCase();
  if (normalized.isEmpty) {
    return fallbackCategory ?? 'Pothole';
  }

  final String? mapped = yoloLabelToCategory[normalized];
  if (mapped != null) {
    return mapped;
  }

  final String normalizedFallback = (fallbackCategory ?? '').trim();
  if (normalizedFallback.isNotEmpty) {
    return normalizedFallback;
  }

  return rawLabel!
      .trim()
      .split(RegExp(r'\s+'))
      .map((String part) {
        if (part.isEmpty) {
          return part;
        }
        return '${part[0].toUpperCase()}${part.substring(1).toLowerCase()}';
      })
      .join(' ');
}

String priorityForCategory(String category) {
  switch (category) {
    case 'Open Manhole':
      return 'critical';
    case 'Pothole':
    case 'Road Obstruction':
    case 'Water Logging':
      return 'high';
    case 'Drainage Blockage':
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

const Map<String, int> priorityRank = <String, int>{
  'low': 0,
  'medium': 1,
  'high': 2,
  'critical': 3,
};

Duration slaForReport({required String category, required String priority}) {
  switch (category) {
    case 'Open Manhole':
      return const Duration(hours: 4);
    case 'Street Light Not Working':
      return const Duration(hours: 24);
    case 'Pothole':
    case 'Road Obstruction':
      return const Duration(hours: 48);
  }

  switch (priority.toLowerCase()) {
    case 'critical':
    case 'high':
      return const Duration(hours: 6);
    case 'medium':
      return const Duration(hours: 24);
    default:
      return const Duration(hours: 48);
  }
}

String elevatePriority(String currentPriority) {
  switch (currentPriority.toLowerCase()) {
    case 'low':
      return 'medium';
    case 'medium':
      return 'high';
    case 'high':
      return 'critical';
    default:
      return 'critical';
  }
}

String smartPriority({
  required String category,
  required int duplicateCount,
  bool slaBreached = false,
}) {
  String resolved = priorityForCategory(category).toLowerCase();

  if (duplicateCount >= 10) {
    resolved = 'critical';
  } else if (duplicateCount >= 5 &&
      (priorityRank[resolved] ?? 0) < (priorityRank['high'] ?? 2)) {
    resolved = 'high';
  }

  if (slaBreached) {
    resolved = elevatePriority(resolved);
  }

  return resolved;
}

List<String> badgesForCitizen({
  required int citizenScore,
  required int reportsSubmitted,
  required int reportsResolved,
}) {
  final List<String> badges = <String>[];
  if (reportsSubmitted >= 1) {
    badges.add('First Reporter');
  }
  if (reportsResolved >= 5) {
    badges.add('City Helper');
  }
  if (citizenScore >= 50) {
    badges.add('Trusted Citizen');
  }
  if (reportsSubmitted >= 25) {
    badges.add('Neighborhood Watch');
  }
  return badges;
}

const List<String> reportStatuses = <String>[
  'Reported',
  'Assigned',
  'In Progress',
  'Under Review',
  'Fixed',
];
