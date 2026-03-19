import 'package:flutter/material.dart';

class IssueCategory {
  const IssueCategory(this.name, this.icon);

  final String name;
  final IconData icon;
}

const List<IssueCategory> issueCategories = <IssueCategory>[
  IssueCategory('Pothole', Icons.warning_amber_rounded),
  IssueCategory('Garbage Dump', Icons.delete_outline_rounded),
  IssueCategory('Water Logging', Icons.flood_rounded),
  IssueCategory('Street Light Issue', Icons.lightbulb_outline_rounded),
];

String priorityForCategory(String category) {
  switch (category) {
    case 'Open Manhole':
      return 'critical';
    case 'Pothole':
    case 'Water Logging':
      return 'high';
    case 'Garbage Dump':
    case 'Garbage Dumping':
    case 'Street Light Issue':
    case 'Street Light Not Working':
      return 'medium';
    default:
      return 'low';
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

const List<String> reportStatuses = <String>[
  'Reported',
  'Assigned',
  'In Progress',
  'Under Review',
  'Fixed',
];
