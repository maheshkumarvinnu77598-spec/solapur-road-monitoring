import 'package:flutter_test/flutter_test.dart';
import 'package:solapur_road_monitoring/reporting/report_config.dart';

void main() {
  group('reporting business rules', () {
    test('priority mapping is correct for required categories', () {
      expect(priorityForCategory('Open Manhole'), 'critical');
      expect(priorityForCategory('Pothole'), 'high');
      expect(priorityForCategory('Water Logging'), 'high');
      expect(priorityForCategory('Garbage Dumping'), 'medium');
      expect(priorityForCategory('Street Light Not Working'), 'medium');
      expect(priorityForCategory('Damaged Footpath'), 'low');
      expect(priorityForCategory('Road Surface Damage'), 'low');
    });

    test('status pipeline remains ordered and complete', () {
      expect(reportStatuses, const <String>[
        'Reported',
        'Assigned',
        'In Progress',
        'Under Review',
        'Fixed',
      ]);
    });

    test('category count stays limited to required 8 categories', () {
      expect(issueCategories.length, 8);
    });
  });
}
