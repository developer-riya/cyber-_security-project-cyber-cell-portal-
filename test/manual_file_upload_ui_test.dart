import 'dart:typed_data';

import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/screens/home/pages/threat_scanner_page.dart';
import 'package:cyberuday/services/manual_file_picker.dart';
import 'package:cyberuday/services/manual_file_upload_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('threat scanner exposes APK and general file upload actions', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: const Scaffold(body: ThreatScannerPage()),
      ),
    );

    expect(find.text('Choose content from this device'), findsOneWidget);
    expect(find.text('Upload APK'), findsOneWidget);
    expect(find.text('Upload file'), findsOneWidget);
  });

  testWidgets('Upload file invokes the picker and shows the selection', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _FakePicker picker = _FakePicker(
      ManualPickedFile(
        name: 'screenshot.png',
        sizeBytes: 4,
        mimeType: 'image/png',
        bytes: Uint8List.fromList(const <int>[1, 2, 3, 4]),
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: Scaffold(
          body: ThreatScannerPage(
            uploadService: ManualFileUploadService(picker: picker),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Upload file'));
    await tester.tap(find.text('Upload file'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(find.text('screenshot.png'), findsOneWidget);
    expect(find.textContaining('Type: Image'), findsOneWidget);
    expect(find.text('Analyze safely'), findsOneWidget);
  });

  testWidgets('cancel closes silently without a failure snackbar', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final _FakePicker picker = _FakePicker(null);
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: Scaffold(
          body: ThreatScannerPage(
            uploadService: ManualFileUploadService(picker: picker),
          ),
        ),
      ),
    );

    await tester.ensureVisible(find.text('Upload file'));
    await tester.tap(find.text('Upload file'));
    await tester.pumpAndSettle();

    expect(picker.calls, 1);
    expect(
      find.text('Cyber Uday could not open the file chooser.'),
      findsNothing,
    );
  });
}

class _FakePicker implements ManualFilePicker {
  _FakePicker(this.file);

  final ManualPickedFile? file;
  int calls = 0;

  @override
  Future<ManualPickedFile?> pickFile({
    required bool apkOnly,
    required int maxBytes,
  }) async {
    calls++;
    return file;
  }
}
