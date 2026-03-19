import 'package:flutter_test/flutter_test.dart';

import 'package:solapur_admin_dashboard/main.dart';

void main() {
  testWidgets('admin app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminDashboardApp());
    expect(find.text('Solapur Road Monitoring'), findsOneWidget);
  });
}
