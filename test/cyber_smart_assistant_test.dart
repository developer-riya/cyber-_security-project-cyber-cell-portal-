import 'package:cyberuday/services/localization_service.dart';
import 'package:cyberuday/widgets/cyber_smart_assistant.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocalizationService.instance.setLocale('en'));

  testWidgets('assistant opens and routes a quick action', (
    WidgetTester tester,
  ) async {
    int? selectedIndex;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: CyberSmartAssistant(
            onNavigate: (index) => selectedIndex = index,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open Cyber Uday Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Cyber Uday Assistant'), findsOneWidget);
    expect(find.text('How can I help you stay safe?'), findsOneWidget);

    await tester.tap(find.text('Check a suspicious link'));
    await tester.pumpAndSettle();
    expect(selectedIndex, 1);
  });

  testWidgets('assistant opens as a bounded mobile surface', (
    WidgetTester tester,
  ) async {
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.binding.setSurfaceSize(const Size(390, 844));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          floatingActionButton: CyberSmartAssistant(onNavigate: (_) {}),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Open Cyber Uday Assistant'));
    await tester.pumpAndSettle();

    expect(find.text('Cyber Uday Assistant'), findsOneWidget);
    expect(find.text('Ask Cyber Uday'), findsOneWidget);
  });
}
