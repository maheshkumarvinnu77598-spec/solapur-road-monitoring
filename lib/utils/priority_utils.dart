import 'package:flutter/material.dart';

Color colorForPriority(String priority) {
  switch (priority.toLowerCase()) {
    case 'critical':
      return Colors.red;
    case 'high':
      return Colors.orange;
    case 'medium':
      return Colors.yellow;
    case 'low':
      return Colors.green;
    default:
      return Colors.grey;
  }
}
