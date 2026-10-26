import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/dev/demo_dashboard_screen.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocalizationService.instance.setLocale('en'));

  testWidgets('demo dashboard uses isolated preview copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: CyberTheme.lightTheme,
        home: const DemoDashboardScreen(),
      ),
    );

    expect(find.text('Development preview'), findsOneWidget);
    expect(
      find.text(
        'This isolated preview uses sample data and is not a signed-in Firebase session.',
      ),
      findsOneWidget,
    );
    expect(find.text('Access Dashboard'), findsNothing);
  });
}
