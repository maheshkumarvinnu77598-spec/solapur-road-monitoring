import 'package:flutter/material.dart';

<<<<<<< HEAD
import '../ui_theme/app_theme.dart';

=======
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
class IssueCategory {
  const IssueCategory(this.name, this.icon);

  final String name;
  final IconData icon;
}

const List<IssueCategory> issueCategories = <IssueCategory>[
  IssueCategory('Pothole', Icons.warning_amber_rounded),
<<<<<<< HEAD
  IssueCategory('Road Surface Damage', Icons.construction_rounded),
  IssueCategory('Incomplete Road Work', Icons.engineering_rounded),
  IssueCategory('Damaged Footpath', Icons.directions_walk_rounded),
  IssueCategory('Water Logging', Icons.flood_rounded),
  IssueCategory('Open Manhole', Icons.dangerous_rounded),
  IssueCategory('Garbage Dumping', Icons.delete_outline_rounded),
  IssueCategory('Street Light Not Working', Icons.lightbulb_outline_rounded),
=======
  IssueCategory('Garbage Dump', Icons.delete_outline_rounded),
  IssueCategory('Water Logging', Icons.flood_rounded),
  IssueCategory('Street Light Issue', Icons.lightbulb_outline_rounded),
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
];

String priorityForCategory(String category) {
  switch (category) {
    case 'Open Manhole':
      return 'critical';
    case 'Pothole':
    case 'Water Logging':
      return 'high';
<<<<<<< HEAD
    case 'Garbage Dumping':
=======
    case 'Garbage Dump':
    case 'Garbage Dumping':
    case 'Street Light Issue':
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
    case 'Street Light Not Working':
      return 'medium';
    default:
      return 'low';
  }
}

<<<<<<< HEAD
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

=======
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
    case 'Street Light Issue':
    case 'Street Light Not Working':
      return const Duration(hours: 24);
    case 'Pothole':
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

>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
const List<String> reportStatuses = <String>[
  'Reported',
  'Assigned',
  'In Progress',
  'Under Review',
  'Fixed',
];
