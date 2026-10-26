import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/models/incoming_share_payload.dart';
import 'package:cyberuday/screens/share_to_scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final IncomingSharePayload linkPayload =
      IncomingSharePayload.fromPlatformMap(<Object?, Object?>{
        'id': 'share-ui',
        'receivedAt': 1,
        'text': 'https://example.test/login',
        'items': const <Object?>[],
      });

  testWidgets('shows a shared link before analysis and routes to the scanner', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: ShareToScanScreen(payload: linkPayload),
      ),
    );

    expect(find.text("Let's check this before you open it."), findsOneWidget);
    expect(find.text('https://example.test/login'), findsOneWidget);

    await tester.tap(find.text('Analyze safely'));
    await tester.pumpAndSettle();

    expect(find.text('Shared content ready to check'), findsOneWidget);
    expect(find.text('No obvious threat detected'), findsOneWidget);
  });
}
