import 'package:cyberuday/screens/splash_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('splash shows the Cyber Uday identity', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: const SplashScreen(),
        ),
      ),
    );
    await tester.pump();

    expect(find.text('CYBER UDAY'), findsOneWidget);
    expect(find.text('Your Digital Bodyguard'), findsOneWidget);
    expect(find.text('Preparing your workspace'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
  });
}
