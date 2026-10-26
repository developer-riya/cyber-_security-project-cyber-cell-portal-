import 'package:cyberuday/core/cyber_branding.dart';
import 'package:cyberuday/core/cyber_design_system.dart';
import 'package:cyberuday/screens/login_screen.dart';
import 'package:cyberuday/screens/signup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('product theme and browser title have one release contract', () {
    expect(CyberTheme.lightTheme.brightness, Brightness.light);
    expect(cyberUdayBrowserTitle, 'Cyber Uday – A Digital Bodyguard');
  });

  testWidgets('login remains light inside an ambient dark host', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const LoginScreen()),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Theme && widget.data.brightness == Brightness.light,
      ),
      findsAtLeastNWidgets(1),
    );
  });

  testWidgets('sign up remains light inside an ambient dark host', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(theme: ThemeData.dark(), home: const SignUpScreen()),
    );

    expect(
      find.byWidgetPredicate(
        (Widget widget) =>
            widget is Theme && widget.data.brightness == Brightness.light,
      ),
      findsAtLeastNWidgets(1),
    );
  });
}
