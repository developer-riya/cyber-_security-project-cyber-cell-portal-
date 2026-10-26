import 'package:cyberuday/core/localization/app_localizations_helper.dart';
import 'package:cyberuday/core/localization/auth_error_localizer.dart';
import 'package:cyberuday/l10n/app_localizations.dart';
import 'package:cyberuday/screens/login_screen.dart';
import 'package:cyberuday/screens/signup_screen.dart';
import 'package:cyberuday/services/auth_service.dart';
import 'package:cyberuday/services/localization_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() => LocalizationService.instance.setLocale('en'));

  testWidgets('citizen sign in uses calm localized English copy', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(
      find.text(
        'Firebase automatically checks sign-in attempts for abuse and may request an additional security check.',
      ),
      findsOneWidget,
    );
    expect(find.text('Forgot password?'), findsOneWidget);
    expect(find.text('AUTHENTICATION NODE'), findsNothing);
    expect(find.text('Threat Level: Guarded'), findsNothing);
    expect(find.text('Admin'), findsNothing);
  });

  testWidgets('citizen sign in follows the selected Hindi locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('hi');
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('वापसी पर स्वागत है'), findsOneWidget);
    expect(find.text('Google के साथ जारी रखें'), findsOneWidget);
    expect(find.text('पासवर्ड भूल गए?'), findsOneWidget);
    expect(find.text('ईमेल पता'), findsOneWidget);
    expect(
      find.text(
        'Firebase साइन-इन प्रयासों में दुरुपयोग की स्वचालित जाँच करता है और ज़रूरत पड़ने पर अतिरिक्त सुरक्षा जाँच माँग सकता है।',
      ),
      findsOneWidget,
    );
  });

  testWidgets('citizen sign in follows the selected Marathi locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('mr');
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('तुमचे स्वागत आहे'), findsOneWidget);
    expect(find.text('Google सह पुढे जा'), findsOneWidget);
    expect(find.text('पासवर्ड विसरलात?'), findsOneWidget);
    expect(find.text('ईमेल पत्ता'), findsOneWidget);
    expect(
      find.text(
        'Firebase साइन-इन प्रयत्नांची गैरवापरासाठी स्वयंचलित तपासणी करते आणि गरज असल्यास अतिरिक्त सुरक्षा तपासणी मागू शकते.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('forgot password validation uses the selected language', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('hi');
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    final Finder forgotPassword = find.text('पासवर्ड भूल गए?');
    await tester.ensureVisible(forgotPassword);
    await tester.tap(forgotPassword);
    await tester.pump();

    expect(find.text('पहले अपना ईमेल पता दर्ज करें।'), findsOneWidget);
  });

  testWidgets('sign up uses the selected Marathi locale', (
    WidgetTester tester,
  ) async {
    LocalizationService.instance.setLocale('mr');
    await tester.pumpWidget(const MaterialApp(home: SignUpScreen()));

    expect(find.text('तुमचे खाते तयार करा'), findsWidgets);
    expect(find.text('ईमेल पत्ता'), findsOneWidget);
    expect(find.text('पासवर्डची पुष्टी करा'), findsOneWidget);
    expect(find.text('खाते तयार करा'), findsOneWidget);
    expect(find.text('Google सह पुढे जा'), findsOneWidget);
  });

  test('auth errors are friendly and localized', () {
    final AppLocalizations hindi = appLocalizationsFor('hi');

    expect(
      localizedAuthError(
        hindi,
        const AuthFailure('technical detail', code: 'wrong-password'),
      ),
      'आपका ईमेल या पासवर्ड सही नहीं है।',
    );
    expect(
      localizedAuthError(
        hindi,
        const AuthFailure('technical detail', code: 'network-request-failed'),
      ),
      'अपना इंटरनेट कनेक्शन जाँचें और फिर प्रयास करें।',
    );
    expect(
      localizedAuthError(
        hindi,
        const AuthFailure('firebase_auth/unknown-code'),
      ),
      'अभी यह अनुरोध पूरा नहीं हो सका। कृपया फिर प्रयास करें।',
    );
    expect(
      localizedAuthError(
        hindi,
        const AuthFailure('redirect', code: 'google-redirect-started'),
      ),
      'Google साइन-इन पर ले जाया जा रहा है...',
    );
  });
}
