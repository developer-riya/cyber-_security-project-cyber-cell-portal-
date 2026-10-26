import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/dev/design_system_showcase.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('design tokens expose semantic values and responsive breakpoints', () {
    expect(CyberColors.background, isNot(CyberColors.primary));
    expect(CyberSpacing.xxs, 4);
    expect(CyberSpacing.page, 48);
    expect(CyberBreakpoints.fromWidth(390), CyberWindowSize.compact);
    expect(CyberBreakpoints.fromWidth(1280), CyberWindowSize.expanded);
  });

  testWidgets('isolated showcase renders the foundation components', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(home: const CyberDesignSystemShowcase()),
    );

    expect(find.text('Foundation preview'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Standard card with a restrained surface.'),
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CyberCard), findsNWidgets(3));
    expect(find.byType(CyberStatusIndicator), findsNWidgets(3));

    await tester.scrollUntilVisible(
      find.byType(CyberInput).first,
      500,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.byType(CyberInput), findsNWidgets(2));
    expect(find.byType(CyberSearchField), findsOneWidget);
    expect(find.text('Primary'), findsOneWidget);
  });
}
