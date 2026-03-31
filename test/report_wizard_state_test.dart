import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:solapur_road_monitoring/reporting/report_wizard_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('camera capture advances wizard to step 2 and does not reset', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1080, 2200));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final XFile image = _sampleXFile();

    await tester.pumpWidget(
      MaterialApp(
        home: ReportWizardScreen(
          repository: null,
          captureImageOverride: () async => image,
        ),
      ),
    );

    await tester.tap(find.text('Pothole'));
    await tester.pump(const Duration(milliseconds: 300));

    final Finder nextButton = find.widgetWithText(FilledButton, 'Next').first;
    await tester.tap(nextButton);
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Capture Image'), findsWidgets);

    final Finder captureButton = find
        .widgetWithText(FilledButton, 'Capture Image')
        .first;
    await tester.ensureVisible(captureButton);
    await tester.tap(captureButton, warnIfMissed: false);
    await tester.pump(const Duration(milliseconds: 350));

    expect(find.text('Location not captured yet.'), findsOneWidget);
  });
}

XFile _sampleXFile() {
  const String base64Png =
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO2G5eQAAAAASUVORK5CYII=';
  final Uint8List bytes = Uint8List.fromList(base64Decode(base64Png));
  return XFile.fromData(bytes, mimeType: 'image/png', name: 'sample.png');
}
