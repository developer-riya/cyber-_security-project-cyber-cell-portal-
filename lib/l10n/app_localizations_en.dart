// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get languageSelectionTitle => 'Choose your language';

  @override
  String get languageSelectionDescription =>
      'Select the language you are most comfortable using.';

  @override
  String get languageSelectionContinue => 'Continue';

  @override
  String get languageSelectionSaving => 'Saving...';

  @override
  String get languageSelectionMore => '+ More Indian languages';

  @override
  String get languageSelectionMoreTitle => 'Indian languages';

  @override
  String get languageSelectionSearchHint => 'Search languages';

  @override
  String get languageSelectionComingSoon => 'Coming soon';

  @override
  String get languageSelectionSelected => 'Selected';

  @override
  String get languageSelectionNotSelected => 'Not selected';

  @override
  String get languageSelectionNoResults => 'No languages found';

  @override
  String get onboardingBrandLine => 'Your Digital Bodyguard';

  @override
  String get onboardingPage1Title => 'Stay protected in the digital world.';

  @override
  String get onboardingPage1Description =>
      'Cyber Uday helps you spot suspicious digital activity and take the next safe step.';

  @override
  String get onboardingPage2Title => 'Detect threats before they grow.';

  @override
  String get onboardingPage2Description =>
      'Check suspicious links and messages, scan for threats, report cybercrime, and get emergency guidance.';

  @override
  String get onboardingPage3Title => 'Protect what matters.';

  @override
  String get onboardingPage3Description =>
      'Cyber Uday is designed to grow with your digital safety needs—for you, your family, your business, and your finances.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingContinue => 'Continue';

  @override
  String get onboardingGetStarted => 'Get Started';

  @override
  String onboardingPageIndicator(int current, int total) {
    return 'Page $current of $total';
  }

  @override
  String get onboardingPage1VisualLabel => 'Cyber Uday protection mark';

  @override
  String get onboardingPage2VisualLabel => 'Link and message safety checks';

  @override
  String get onboardingPage3VisualLabel =>
      'Protection for people, work, and finances';

  @override
  String get authBrandLine => 'Your Digital Bodyguard';

  @override
  String get authWelcomeBack => 'Welcome back';

  @override
  String get authSignInIntro =>
      'Stay protected from digital threats, fraud, and cybercrime.';

  @override
  String get authEmailLabel => 'Email address';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get authContinueGoogle => 'Continue with Google';

  @override
  String get authSecurityNotice =>
      'Firebase automatically checks sign-in attempts for abuse and may request an additional security check.';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authNoAccount => 'Don\'t have an account?';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authEmailValidation => 'Enter a valid email address.';

  @override
  String get authPasswordValidation => 'Enter your password.';

  @override
  String get authResetEmailPrompt => 'Enter your email address first.';

  @override
  String authResetEmailSent(Object email) {
    return 'Password reset link sent to $email.';
  }

  @override
  String get authSignUpTitle => 'Create your account';

  @override
  String get authSignUpIntro =>
      'Create a Cyber Uday account to continue your digital safety journey.';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authCreateAccountAction => 'Create account';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authPasswordLengthValidation =>
      'Use a password with at least 6 characters.';

  @override
  String get authPasswordMismatch => 'Passwords do not match.';

  @override
  String get authErrorIncorrectCredentials =>
      'Your email or password is incorrect.';

  @override
  String get authErrorInvalidCredential =>
      'Those sign-in details are invalid or expired.';

  @override
  String get authErrorAccountDifferent =>
      'This email is already linked to another sign-in method.';

  @override
  String get authErrorInvalidEmail => 'Enter a valid email address.';

  @override
  String get authErrorEmailInUse => 'That email is already registered.';

  @override
  String get authErrorWeakPassword =>
      'Use a password with at least 6 characters.';

  @override
  String get authErrorNetwork =>
      'Check your internet connection and try again.';

  @override
  String get authErrorUserDisabled =>
      'This account has been disabled. Contact support for help.';

  @override
  String get authErrorTooManyRequests =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get authErrorSecurityCheck =>
      'The security check could not be completed. Try again.';

  @override
  String get authErrorPopupBlocked =>
      'Allow pop-ups for Google sign-in and try again.';

  @override
  String get authErrorOperationDisabled =>
      'This sign-in method is not available right now.';

  @override
  String get authErrorGoogleCancelled => 'Google sign-in was cancelled.';

  @override
  String get authErrorGoogleFailed =>
      'We could not sign you in with Google right now.';

  @override
  String get authErrorGoogleRedirecting => 'Redirecting to Google sign-in...';

  @override
  String get authErrorWebConfiguration =>
      'Google sign-in is not enabled for this website yet.';

  @override
  String get authErrorSignInFailed =>
      'We could not sign you in right now. Please try again.';

  @override
  String get authErrorSignUpFailed =>
      'We could not create your account right now. Please try again.';

  @override
  String get authErrorResetFailed =>
      'We could not send the reset email right now. Please try again.';

  @override
  String get authErrorGeneric =>
      'We could not complete that request right now. Please try again.';

  @override
  String get authSignUpBeforeContinue => 'Before you continue';

  @override
  String get authSignUpNoteEmail => 'Use an email address you can access.';

  @override
  String get authSignUpNoteNext =>
      'After creating your account, you can continue to Cyber Uday.';

  @override
  String get authDevAccessDashboard => 'Access Dashboard';

  @override
  String get authDevPreview => 'Development preview';

  @override
  String get authDemoTitle => 'Development preview';

  @override
  String get authDemoDescription =>
      'This isolated preview uses sample data and is not a signed-in Firebase session.';

  @override
  String get authDemoProtectionLabel => 'Protection status';

  @override
  String get authDemoProtectionValue => 'Ready';

  @override
  String get authDemoThreatLabel => 'Threat checks';

  @override
  String get authDemoThreatValue => '3 sample results';

  @override
  String get authDemoAlertsLabel => 'Alerts';

  @override
  String get authDemoAlertsValue => 'No active alerts';

  @override
  String get authDemoExit => 'Exit preview';
}
