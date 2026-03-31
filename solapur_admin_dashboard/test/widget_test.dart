import 'package:flutter_test/flutter_test.dart';

<<<<<<< HEAD
void main() {
  test('basic sanity check', () {
    expect(1 + 1, 2);
=======
import 'package:solapur_admin_dashboard/main.dart';

void main() {
  testWidgets('admin app boots', (WidgetTester tester) async {
    await tester.pumpWidget(const AdminDashboardApp());
    expect(find.text('Solapur Road Monitoring'), findsOneWidget);
>>>>>>> 0957bededdaab9cc21b7e75c4984775a3603902c
  });
}
