import 'package:cyberuday/screens/onboarding_screen.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:cyberuday/services/onboarding_preference_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LocalizationService.instance.setLocale('en');
  });

  testWidgets('onboarding pages advance through the full journey', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('Stay protected in the digital world.'), findsOneWidget);
    expect(find.text('Continue'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Detect threats before they grow.'), findsOneWidget);

    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(find.text('Protect what matters.'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('skip completes onboarding and reaches authentication boundary', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          destinationBuilder: (_) => const Text('Authentication'),
        ),
      ),
    );

    await tester.tap(find.text('Skip'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication'), findsOneWidget);
    expect(await OnboardingPreferenceService.instance.isComplete(), isTrue);
  });

  testWidgets('final Get Started completes onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: OnboardingScreen(
          destinationBuilder: (_) => const Text('Authentication'),
        ),
      ),
    );

    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(PageView), const Offset(-500, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    expect(find.text('Authentication'), findsOneWidget);
    expect(await OnboardingPreferenceService.instance.isComplete(), isTrue);
  });

  testWidgets('Hindi onboarding uses the selected locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('hi');
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('डिजिटल दुनिया में सुरक्षित रहें।'), findsOneWidget);
    expect(find.text('आगे बढ़ें'), findsOneWidget);
  });

  testWidgets('Marathi onboarding uses the selected locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('mr');
    await tester.pumpWidget(const MaterialApp(home: OnboardingScreen()));

    expect(find.text('डिजिटल जगात सुरक्षित राहा.'), findsOneWidget);
    expect(find.text('पुढे जा'), findsOneWidget);
  });

  test('onboarding completion persists for returning users', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final OnboardingPreferenceService service = OnboardingPreferenceService(
      preferences: preferences,
    );

    expect(await service.isComplete(), isFalse);
    await service.markComplete();
    expect(await service.isComplete(), isTrue);
  });
}
