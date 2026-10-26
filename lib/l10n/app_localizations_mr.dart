// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Marathi (`mr`).
class AppLocalizationsMr extends AppLocalizations {
  AppLocalizationsMr([String locale = 'mr']) : super(locale);

  @override
  String get languageSelectionTitle => 'तुमची भाषा निवडा';

  @override
  String get languageSelectionDescription =>
      'तुम्हाला सर्वात सोयीची वाटणारी भाषा निवडा.';

  @override
  String get languageSelectionContinue => 'पुढे जा';

  @override
  String get languageSelectionSaving => 'जतन करत आहे...';

  @override
  String get languageSelectionMore => '+ अधिक भारतीय भाषा';

  @override
  String get languageSelectionMoreTitle => 'भारतीय भाषा';

  @override
  String get languageSelectionSearchHint => 'भाषा शोधा';

  @override
  String get languageSelectionComingSoon => 'लवकरच उपलब्ध';

  @override
  String get languageSelectionSelected => 'निवडले';

  @override
  String get languageSelectionNotSelected => 'निवडलेले नाही';

  @override
  String get languageSelectionNoResults => 'कोणतीही भाषा सापडली नाही';

  @override
  String get onboardingBrandLine => 'तुमचा डिजिटल बॉडीगार्ड';

  @override
  String get onboardingPage1Title => 'डिजिटल जगात सुरक्षित राहा.';

  @override
  String get onboardingPage1Description =>
      'सायबर उदय तुम्हाला संशयास्पद डिजिटल हालचाली ओळखण्यास आणि पुढचे सुरक्षित पाऊल उचलण्यास मदत करतो.';

  @override
  String get onboardingPage2Title => 'धोके वाढण्यापूर्वी ओळखा.';

  @override
  String get onboardingPage2Description =>
      'संशयास्पद लिंक आणि संदेश तपासा, धोके स्कॅन करा, सायबर गुन्ह्यांची तक्रार करा आणि आपत्कालीन मार्गदर्शन मिळवा.';

  @override
  String get onboardingPage3Title => 'महत्त्वाच्या गोष्टींचे संरक्षण करा.';

  @override
  String get onboardingPage3Description =>
      'सायबर उदय तुमच्या डिजिटल सुरक्षिततेच्या गरजांसोबत वाढण्यासाठी तयार केले आहे—तुमच्यासाठी, कुटुंबासाठी, व्यवसायासाठी आणि आर्थिक बाबींसाठी.';

  @override
  String get onboardingSkip => 'वगळा';

  @override
  String get onboardingContinue => 'पुढे जा';

  @override
  String get onboardingGetStarted => 'सुरुवात करा';

  @override
  String onboardingPageIndicator(int current, int total) {
    return 'पृष्ठ $current / $total';
  }

  @override
  String get onboardingPage1VisualLabel => 'सायबर उदय सुरक्षा चिन्ह';

  @override
  String get onboardingPage2VisualLabel => 'लिंक आणि संदेश सुरक्षा तपासणी';

  @override
  String get onboardingPage3VisualLabel =>
      'लोक, काम आणि आर्थिक बाबींसाठी सुरक्षा';

  @override
  String get authBrandLine => 'तुमचा डिजिटल बॉडीगार्ड';

  @override
  String get authWelcomeBack => 'तुमचे स्वागत आहे';

  @override
  String get authSignInIntro =>
      'डिजिटल धोके, फसवणूक आणि सायबर गुन्ह्यांपासून सुरक्षित राहण्यास मदत मिळवा.';

  @override
  String get authEmailLabel => 'ईमेल पत्ता';

  @override
  String get authPasswordLabel => 'पासवर्ड';

  @override
  String get authSignIn => 'साइन इन करा';

  @override
  String get authContinueGoogle => 'Google सह पुढे जा';

  @override
  String get authSecurityNotice =>
      'Firebase साइन-इन प्रयत्नांची गैरवापरासाठी स्वयंचलित तपासणी करते आणि गरज असल्यास अतिरिक्त सुरक्षा तपासणी मागू शकते.';

  @override
  String get authForgotPassword => 'पासवर्ड विसरलात?';

  @override
  String get authNoAccount => 'तुमचे खाते नाही का?';

  @override
  String get authCreateAccount => 'खाते तयार करा';

  @override
  String get authEmailValidation => 'वैध ईमेल पत्ता टाका.';

  @override
  String get authPasswordValidation => 'तुमचा पासवर्ड टाका.';

  @override
  String get authResetEmailPrompt => 'आधी तुमचा ईमेल पत्ता टाका.';

  @override
  String authResetEmailSent(Object email) {
    return 'पासवर्ड रीसेट लिंक $email वर पाठवली आहे.';
  }

  @override
  String get authSignUpTitle => 'तुमचे खाते तयार करा';

  @override
  String get authSignUpIntro =>
      'तुमचा डिजिटल सुरक्षिततेचा प्रवास सुरू ठेवण्यासाठी सायबर उदय खाते तयार करा.';

  @override
  String get authConfirmPassword => 'पासवर्डची पुष्टी करा';

  @override
  String get authCreateAccountAction => 'खाते तयार करा';

  @override
  String get authBackToSignIn => 'साइन इनवर परत जा';

  @override
  String get authPasswordLengthValidation => 'किमान ६ अक्षरांचा पासवर्ड वापरा.';

  @override
  String get authPasswordMismatch => 'पासवर्ड जुळत नाहीत.';

  @override
  String get authErrorIncorrectCredentials =>
      'तुमचा ईमेल किंवा पासवर्ड चुकीचा आहे.';

  @override
  String get authErrorInvalidCredential =>
      'साइन-इन तपशील अवैध किंवा कालबाह्य आहेत.';

  @override
  String get authErrorAccountDifferent =>
      'हा ईमेल आधीच दुसऱ्या साइन-इन पद्धतीशी जोडलेला आहे.';

  @override
  String get authErrorInvalidEmail => 'वैध ईमेल पत्ता टाका.';

  @override
  String get authErrorEmailInUse => 'हा ईमेल आधीच नोंदणीकृत आहे.';

  @override
  String get authErrorWeakPassword => 'किमान ६ अक्षरांचा पासवर्ड वापरा.';

  @override
  String get authErrorNetwork =>
      'तुमचे इंटरनेट कनेक्शन तपासा आणि पुन्हा प्रयत्न करा.';

  @override
  String get authErrorUserDisabled =>
      'हे खाते बंद केले आहे. मदतीसाठी संपर्क करा.';

  @override
  String get authErrorTooManyRequests =>
      'खूप प्रयत्न झाले. थोड्या वेळाने पुन्हा प्रयत्न करा.';

  @override
  String get authErrorSecurityCheck =>
      'सुरक्षा तपासणी पूर्ण होऊ शकली नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get authErrorPopupBlocked =>
      'Google साइन-इनसाठी पॉप-अपला परवानगी द्या आणि पुन्हा प्रयत्न करा.';

  @override
  String get authErrorOperationDisabled =>
      'ही साइन-इन पद्धत सध्या उपलब्ध नाही.';

  @override
  String get authErrorGoogleCancelled => 'Google साइन-इन रद्द केले.';

  @override
  String get authErrorGoogleFailed =>
      'आत्ता Google द्वारे साइन इन करता आले नाही.';

  @override
  String get authErrorGoogleRedirecting => 'Google साइन-इनकडे वळवत आहे...';

  @override
  String get authErrorWebConfiguration =>
      'या वेबसाइटसाठी Google साइन-इन अजून सक्षम केलेले नाही.';

  @override
  String get authErrorSignInFailed =>
      'आत्ता साइन इन करता आले नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get authErrorSignUpFailed =>
      'आत्ता खाते तयार करता आले नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get authErrorResetFailed =>
      'आत्ता रीसेट ईमेल पाठवता आले नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get authErrorGeneric =>
      'आत्ता विनंती पूर्ण करता आली नाही. कृपया पुन्हा प्रयत्न करा.';

  @override
  String get authSignUpBeforeContinue => 'पुढे जाण्यापूर्वी';

  @override
  String get authSignUpNoteEmail => 'तुम्ही वापरू शकता असा ईमेल पत्ता वापरा.';

  @override
  String get authSignUpNoteNext =>
      'खाते तयार केल्यानंतर तुम्ही सायबर उदयवर पुढे जाऊ शकता.';

  @override
  String get authDevAccessDashboard => 'डॅशबोर्ड उघडा';

  @override
  String get authDevPreview => 'डेव्हलपमेंट प्रीव्यू';

  @override
  String get authDemoTitle => 'डेव्हलपमेंट प्रीव्यू';

  @override
  String get authDemoDescription =>
      'हा वेगळा प्रीव्यू नमुना डेटा वापरतो आणि Firebase सत्रात साइन इन करत नाही.';

  @override
  String get authDemoProtectionLabel => 'सुरक्षा स्थिती';

  @override
  String get authDemoProtectionValue => 'तयार';

  @override
  String get authDemoThreatLabel => 'धोका तपासणी';

  @override
  String get authDemoThreatValue => '3 नमुना परिणाम';

  @override
  String get authDemoAlertsLabel => 'अलर्ट';

  @override
  String get authDemoAlertsValue => 'कोणतेही सक्रिय अलर्ट नाहीत';

  @override
  String get authDemoExit => 'प्रीव्यूमधून बाहेर पडा';
}
