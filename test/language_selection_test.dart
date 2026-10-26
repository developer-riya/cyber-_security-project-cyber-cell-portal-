import 'package:cyberuday/core/localization/supported_language.dart';
import 'package:cyberuday/screens/language_selection_screen.dart';
import 'package:cyberuday/screens/onboarding_screen.dart';
import 'package:cyberuday/screens/splash_screen.dart';
import 'package:cyberuday/services/language_preference_service.dart';
import 'package:cyberuday/services/launch_flow_service.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    LocalizationService.instance.setLocale('en');
  });

  test('the language catalog contains all 23 defined languages', () {
    const Set<String> expectedCodes = <String>{
      'as',
      'bn',
      'brx',
      'doi',
      'en',
      'gu',
      'hi',
      'kn',
      'ks',
      'kok',
      'mai',
      'ml',
      'mni',
      'mr',
      'ne',
      'or',
      'pa',
      'sa',
      'sat',
      'sd',
      'ta',
      'te',
      'ur',
    };

    expect(SupportedLanguage.all, hasLength(23));
    expect(
      SupportedLanguage.all.map((SupportedLanguage language) => language.code),
      containsAll(expectedCodes),
    );
    expect(SupportedLanguage.primary, hasLength(3));
    expect(
      SupportedLanguage.primary.every(
        (SupportedLanguage language) =>
            language.isAvailable && language.isTranslated,
      ),
      isTrue,
    );
  });

  testWidgets('language options render and selection is visible', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LanguageSelectionScreen()));

    expect(find.text('English'), findsOneWidget);
    expect(find.text('हिन्दी'), findsOneWidget);
    expect(find.text('मराठी'), findsOneWidget);
    expect(find.text('অসমীয়া'), findsNothing);
    expect(find.byIcon(Icons.check_circle_rounded), findsNothing);

    await tester.tap(find.text('हिन्दी'));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
    expect(find.text('अपनी भाषा चुनें'), findsOneWidget);
    expect(find.text('आगे बढ़ें'), findsOneWidget);
    expect(LocalizationService.instance.currentLocale.value, 'hi');
  });

  testWidgets('more languages opens a searchable catalog', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LanguageSelectionScreen()));

    await tester.tap(find.text('+ More Indian languages'));
    await tester.pumpAndSettle();

    expect(find.text('Indian languages'), findsOneWidget);
    expect(find.text('অসমীয়া'), findsOneWidget);
    expect(find.text('Coming soon'), findsWidgets);

    await tester.enterText(find.byType(TextField), 'Tamil');
    await tester.pump();

    expect(find.text('தமிழ்'), findsOneWidget);
    expect(find.text('Tamil'), findsWidgets);
    expect(find.text('Coming soon'), findsOneWidget);
  });

  testWidgets('language selection continues into onboarding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LanguageSelectionScreen()));

    await tester.tap(find.text('English'));
    await tester.pump();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingScreen), findsOneWidget);
  });

  test(
    'language preference persists and restores a supported language',
    () async {
      final SharedPreferences preferences =
          await SharedPreferences.getInstance();
      final LanguagePreferenceService service = LanguagePreferenceService(
        preferences: preferences,
      );

      await service.save(SupportedLanguage.all[2]);

      expect(await service.load(), SupportedLanguage.all[2]);
    },
  );

  test('first launch resolves to language selection', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LanguagePreferenceService service = LanguagePreferenceService(
      preferences: preferences,
    );
    final LaunchFlowService flow = LaunchFlowService(preferences: service);

    expect(await flow.resolve(), LaunchDestination.languageSelection);
  });

  test('returning users resolve to the existing flow', () async {
    final SharedPreferences preferences = await SharedPreferences.getInstance();
    final LanguagePreferenceService service = LanguagePreferenceService(
      preferences: preferences,
    );
    final LaunchFlowService flow = LaunchFlowService(preferences: service);

    await service.save(SupportedLanguage.all.first);

    expect(await flow.resolve(), LaunchDestination.existingFlow);
  });

  test('missing translations safely fall back to English', () {
    LocalizationService.instance.setLocale('ta');

    expect(LocalizationService.instance.translate('welcome'), 'Welcome Back');
  });

  testWidgets('first launch routes from splash to language selection', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: SplashScreen()));
    await tester.pump(const Duration(milliseconds: 2200));
    await tester.pumpAndSettle();

    expect(find.byType(LanguageSelectionScreen), findsOneWidget);
  });
}
