import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';
import 'app_localizations_mr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hi'),
    Locale('mr'),
  ];

  /// No description provided for @languageSelectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Choose your language'**
  String get languageSelectionTitle;

  /// No description provided for @languageSelectionDescription.
  ///
  /// In en, this message translates to:
  /// **'Select the language you are most comfortable using.'**
  String get languageSelectionDescription;

  /// No description provided for @languageSelectionContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get languageSelectionContinue;

  /// No description provided for @languageSelectionSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving...'**
  String get languageSelectionSaving;

  /// No description provided for @languageSelectionMore.
  ///
  /// In en, this message translates to:
  /// **'+ More Indian languages'**
  String get languageSelectionMore;

  /// No description provided for @languageSelectionMoreTitle.
  ///
  /// In en, this message translates to:
  /// **'Indian languages'**
  String get languageSelectionMoreTitle;

  /// No description provided for @languageSelectionSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search languages'**
  String get languageSelectionSearchHint;

  /// No description provided for @languageSelectionComingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get languageSelectionComingSoon;

  /// No description provided for @languageSelectionSelected.
  ///
  /// In en, this message translates to:
  /// **'Selected'**
  String get languageSelectionSelected;

  /// No description provided for @languageSelectionNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Not selected'**
  String get languageSelectionNotSelected;

  /// No description provided for @languageSelectionNoResults.
  ///
  /// In en, this message translates to:
  /// **'No languages found'**
  String get languageSelectionNoResults;

  /// No description provided for @onboardingBrandLine.
  ///
  /// In en, this message translates to:
  /// **'Your Digital Bodyguard'**
  String get onboardingBrandLine;

  /// No description provided for @onboardingPage1Title.
  ///
  /// In en, this message translates to:
  /// **'Stay protected in the digital world.'**
  String get onboardingPage1Title;

  /// No description provided for @onboardingPage1Description.
  ///
  /// In en, this message translates to:
  /// **'Cyber Uday helps you spot suspicious digital activity and take the next safe step.'**
  String get onboardingPage1Description;

  /// No description provided for @onboardingPage2Title.
  ///
  /// In en, this message translates to:
  /// **'Detect threats before they grow.'**
  String get onboardingPage2Title;

  /// No description provided for @onboardingPage2Description.
  ///
  /// In en, this message translates to:
  /// **'Check suspicious links and messages, scan for threats, report cybercrime, and get emergency guidance.'**
  String get onboardingPage2Description;

  /// No description provided for @onboardingPage3Title.
  ///
  /// In en, this message translates to:
  /// **'Protect what matters.'**
  String get onboardingPage3Title;

  /// No description provided for @onboardingPage3Description.
  ///
  /// In en, this message translates to:
  /// **'Cyber Uday is designed to grow with your digital safety needs—for you, your family, your business, and your finances.'**
  String get onboardingPage3Description;

  /// No description provided for @onboardingSkip.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get onboardingSkip;

  /// No description provided for @onboardingContinue.
  ///
  /// In en, this message translates to:
  /// **'Continue'**
  String get onboardingContinue;

  /// No description provided for @onboardingGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get onboardingGetStarted;

  /// No description provided for @onboardingPageIndicator.
  ///
  /// In en, this message translates to:
  /// **'Page {current} of {total}'**
  String onboardingPageIndicator(int current, int total);

  /// No description provided for @onboardingPage1VisualLabel.
  ///
  /// In en, this message translates to:
  /// **'Cyber Uday protection mark'**
  String get onboardingPage1VisualLabel;

  /// No description provided for @onboardingPage2VisualLabel.
  ///
  /// In en, this message translates to:
  /// **'Link and message safety checks'**
  String get onboardingPage2VisualLabel;

  /// No description provided for @onboardingPage3VisualLabel.
  ///
  /// In en, this message translates to:
  /// **'Protection for people, work, and finances'**
  String get onboardingPage3VisualLabel;

  /// No description provided for @authBrandLine.
  ///
  /// In en, this message translates to:
  /// **'Your Digital Bodyguard'**
  String get authBrandLine;

  /// No description provided for @authWelcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get authWelcomeBack;

  /// No description provided for @authSignInIntro.
  ///
  /// In en, this message translates to:
  /// **'Stay protected from digital threats, fraud, and cybercrime.'**
  String get authSignInIntro;

  /// No description provided for @authEmailLabel.
  ///
  /// In en, this message translates to:
  /// **'Email address'**
  String get authEmailLabel;

  /// No description provided for @authPasswordLabel.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPasswordLabel;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @authContinueGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authContinueGoogle;

  /// No description provided for @authSecurityNotice.
  ///
  /// In en, this message translates to:
  /// **'Firebase automatically checks sign-in attempts for abuse and may request an additional security check.'**
  String get authSecurityNotice;

  /// No description provided for @authForgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgotPassword;

  /// No description provided for @authNoAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get authNoAccount;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authEmailValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authEmailValidation;

  /// No description provided for @authPasswordValidation.
  ///
  /// In en, this message translates to:
  /// **'Enter your password.'**
  String get authPasswordValidation;

  /// No description provided for @authResetEmailPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address first.'**
  String get authResetEmailPrompt;

  /// No description provided for @authResetEmailSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset link sent to {email}.'**
  String authResetEmailSent(Object email);

  /// No description provided for @authSignUpTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authSignUpTitle;

  /// No description provided for @authSignUpIntro.
  ///
  /// In en, this message translates to:
  /// **'Create a Cyber Uday account to continue your digital safety journey.'**
  String get authSignUpIntro;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authCreateAccountAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccountAction;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authPasswordLengthValidation.
  ///
  /// In en, this message translates to:
  /// **'Use a password with at least 6 characters.'**
  String get authPasswordLengthValidation;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get authPasswordMismatch;

  /// No description provided for @authErrorIncorrectCredentials.
  ///
  /// In en, this message translates to:
  /// **'Your email or password is incorrect.'**
  String get authErrorIncorrectCredentials;

  /// No description provided for @authErrorInvalidCredential.
  ///
  /// In en, this message translates to:
  /// **'Those sign-in details are invalid or expired.'**
  String get authErrorInvalidCredential;

  /// No description provided for @authErrorAccountDifferent.
  ///
  /// In en, this message translates to:
  /// **'This email is already linked to another sign-in method.'**
  String get authErrorAccountDifferent;

  /// No description provided for @authErrorInvalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid email address.'**
  String get authErrorInvalidEmail;

  /// No description provided for @authErrorEmailInUse.
  ///
  /// In en, this message translates to:
  /// **'That email is already registered.'**
  String get authErrorEmailInUse;

  /// No description provided for @authErrorWeakPassword.
  ///
  /// In en, this message translates to:
  /// **'Use a password with at least 6 characters.'**
  String get authErrorWeakPassword;

  /// No description provided for @authErrorNetwork.
  ///
  /// In en, this message translates to:
  /// **'Check your internet connection and try again.'**
  String get authErrorNetwork;

  /// No description provided for @authErrorUserDisabled.
  ///
  /// In en, this message translates to:
  /// **'This account has been disabled. Contact support for help.'**
  String get authErrorUserDisabled;

  /// No description provided for @authErrorTooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Wait a moment and try again.'**
  String get authErrorTooManyRequests;

  /// No description provided for @authErrorSecurityCheck.
  ///
  /// In en, this message translates to:
  /// **'The security check could not be completed. Try again.'**
  String get authErrorSecurityCheck;

  /// No description provided for @authErrorPopupBlocked.
  ///
  /// In en, this message translates to:
  /// **'Allow pop-ups for Google sign-in and try again.'**
  String get authErrorPopupBlocked;

  /// No description provided for @authErrorOperationDisabled.
  ///
  /// In en, this message translates to:
  /// **'This sign-in method is not available right now.'**
  String get authErrorOperationDisabled;

  /// No description provided for @authErrorGoogleCancelled.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in was cancelled.'**
  String get authErrorGoogleCancelled;

  /// No description provided for @authErrorGoogleFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not sign you in with Google right now.'**
  String get authErrorGoogleFailed;

  /// No description provided for @authErrorGoogleRedirecting.
  ///
  /// In en, this message translates to:
  /// **'Redirecting to Google sign-in...'**
  String get authErrorGoogleRedirecting;

  /// No description provided for @authErrorWebConfiguration.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in is not enabled for this website yet.'**
  String get authErrorWebConfiguration;

  /// No description provided for @authErrorSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not sign you in right now. Please try again.'**
  String get authErrorSignInFailed;

  /// No description provided for @authErrorSignUpFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not create your account right now. Please try again.'**
  String get authErrorSignUpFailed;

  /// No description provided for @authErrorResetFailed.
  ///
  /// In en, this message translates to:
  /// **'We could not send the reset email right now. Please try again.'**
  String get authErrorResetFailed;

  /// No description provided for @authErrorGeneric.
  ///
  /// In en, this message translates to:
  /// **'We could not complete that request right now. Please try again.'**
  String get authErrorGeneric;

  /// No description provided for @authSignUpBeforeContinue.
  ///
  /// In en, this message translates to:
  /// **'Before you continue'**
  String get authSignUpBeforeContinue;

  /// No description provided for @authSignUpNoteEmail.
  ///
  /// In en, this message translates to:
  /// **'Use an email address you can access.'**
  String get authSignUpNoteEmail;

  /// No description provided for @authSignUpNoteNext.
  ///
  /// In en, this message translates to:
  /// **'After creating your account, you can continue to Cyber Uday.'**
  String get authSignUpNoteNext;

  /// No description provided for @authDevAccessDashboard.
  ///
  /// In en, this message translates to:
  /// **'Access Dashboard'**
  String get authDevAccessDashboard;

  /// No description provided for @authDevPreview.
  ///
  /// In en, this message translates to:
  /// **'Development preview'**
  String get authDevPreview;

  /// No description provided for @authDemoTitle.
  ///
  /// In en, this message translates to:
  /// **'Development preview'**
  String get authDemoTitle;

  /// No description provided for @authDemoDescription.
  ///
  /// In en, this message translates to:
  /// **'This isolated preview uses sample data and is not a signed-in Firebase session.'**
  String get authDemoDescription;

  /// No description provided for @authDemoProtectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Protection status'**
  String get authDemoProtectionLabel;

  /// No description provided for @authDemoProtectionValue.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get authDemoProtectionValue;

  /// No description provided for @authDemoThreatLabel.
  ///
  /// In en, this message translates to:
  /// **'Threat checks'**
  String get authDemoThreatLabel;

  /// No description provided for @authDemoThreatValue.
  ///
  /// In en, this message translates to:
  /// **'3 sample results'**
  String get authDemoThreatValue;

  /// No description provided for @authDemoAlertsLabel.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get authDemoAlertsLabel;

  /// No description provided for @authDemoAlertsValue.
  ///
  /// In en, this message translates to:
  /// **'No active alerts'**
  String get authDemoAlertsValue;

  /// No description provided for @authDemoExit.
  ///
  /// In en, this message translates to:
  /// **'Exit preview'**
  String get authDemoExit;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hi', 'mr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
    case 'mr':
      return AppLocalizationsMr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
