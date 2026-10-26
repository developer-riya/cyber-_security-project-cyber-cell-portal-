// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Hindi (`hi`).
class AppLocalizationsHi extends AppLocalizations {
  AppLocalizationsHi([String locale = 'hi']) : super(locale);

  @override
  String get languageSelectionTitle => 'अपनी भाषा चुनें';

  @override
  String get languageSelectionDescription =>
      'वह भाषा चुनें जिसमें आप सबसे सहज महसूस करते हैं।';

  @override
  String get languageSelectionContinue => 'आगे बढ़ें';

  @override
  String get languageSelectionSaving => 'सहेजा जा रहा है...';

  @override
  String get languageSelectionMore => '+ अधिक भारतीय भाषाएँ';

  @override
  String get languageSelectionMoreTitle => 'भारतीय भाषाएँ';

  @override
  String get languageSelectionSearchHint => 'भाषाएँ खोजें';

  @override
  String get languageSelectionComingSoon => 'जल्द आ रहा है';

  @override
  String get languageSelectionSelected => 'चयनित';

  @override
  String get languageSelectionNotSelected => 'चयनित नहीं';

  @override
  String get languageSelectionNoResults => 'कोई भाषा नहीं मिली';

  @override
  String get onboardingBrandLine => 'आपका डिजिटल बॉडीगार्ड';

  @override
  String get onboardingPage1Title => 'डिजिटल दुनिया में सुरक्षित रहें।';

  @override
  String get onboardingPage1Description =>
      'साइबर उदय आपको संदिग्ध डिजिटल गतिविधि पहचानने और अगला सुरक्षित कदम उठाने में मदद करता है।';

  @override
  String get onboardingPage2Title => 'खतरों को बढ़ने से पहले पहचानें।';

  @override
  String get onboardingPage2Description =>
      'संदिग्ध लिंक और संदेश जाँचें, खतरों को स्कैन करें, साइबर अपराध की रिपोर्ट करें और आपातकालीन मार्गदर्शन पाएँ।';

  @override
  String get onboardingPage3Title => 'जो मायने रखता है उसकी रक्षा करें।';

  @override
  String get onboardingPage3Description =>
      'साइबर उदय आपकी डिजिटल सुरक्षा की ज़रूरतों के साथ आगे बढ़ने के लिए बनाया गया है—आपके, परिवार, व्यवसाय और वित्त के लिए।';

  @override
  String get onboardingSkip => 'छोड़ें';

  @override
  String get onboardingContinue => 'आगे बढ़ें';

  @override
  String get onboardingGetStarted => 'शुरू करें';

  @override
  String onboardingPageIndicator(int current, int total) {
    return 'पृष्ठ $current / $total';
  }

  @override
  String get onboardingPage1VisualLabel => 'साइबर उदय सुरक्षा चिह्न';

  @override
  String get onboardingPage2VisualLabel => 'लिंक और संदेश सुरक्षा जाँच';

  @override
  String get onboardingPage3VisualLabel => 'लोगों, काम और वित्त के लिए सुरक्षा';

  @override
  String get authBrandLine => 'आपका डिजिटल बॉडीगार्ड';

  @override
  String get authWelcomeBack => 'वापसी पर स्वागत है';

  @override
  String get authSignInIntro =>
      'डिजिटल खतरों, धोखाधड़ी और साइबर अपराध से सुरक्षित रहने में मदद पाएँ।';

  @override
  String get authEmailLabel => 'ईमेल पता';

  @override
  String get authPasswordLabel => 'पासवर्ड';

  @override
  String get authSignIn => 'साइन इन करें';

  @override
  String get authContinueGoogle => 'Google के साथ जारी रखें';

  @override
  String get authSecurityNotice =>
      'Firebase साइन-इन प्रयासों में दुरुपयोग की स्वचालित जाँच करता है और ज़रूरत पड़ने पर अतिरिक्त सुरक्षा जाँच माँग सकता है।';

  @override
  String get authForgotPassword => 'पासवर्ड भूल गए?';

  @override
  String get authNoAccount => 'क्या आपका खाता नहीं है?';

  @override
  String get authCreateAccount => 'खाता बनाएँ';

  @override
  String get authEmailValidation => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get authPasswordValidation => 'अपना पासवर्ड दर्ज करें।';

  @override
  String get authResetEmailPrompt => 'पहले अपना ईमेल पता दर्ज करें।';

  @override
  String authResetEmailSent(Object email) {
    return 'पासवर्ड रीसेट लिंक $email पर भेज दिया गया है।';
  }

  @override
  String get authSignUpTitle => 'अपना खाता बनाएँ';

  @override
  String get authSignUpIntro =>
      'अपनी डिजिटल सुरक्षा यात्रा जारी रखने के लिए साइबर उदय खाता बनाएँ।';

  @override
  String get authConfirmPassword => 'पासवर्ड की पुष्टि करें';

  @override
  String get authCreateAccountAction => 'खाता बनाएँ';

  @override
  String get authBackToSignIn => 'साइन इन पर वापस जाएँ';

  @override
  String get authPasswordLengthValidation =>
      'कम से कम 6 अक्षरों का पासवर्ड इस्तेमाल करें।';

  @override
  String get authPasswordMismatch => 'पासवर्ड मेल नहीं खाते।';

  @override
  String get authErrorIncorrectCredentials =>
      'आपका ईमेल या पासवर्ड सही नहीं है।';

  @override
  String get authErrorInvalidCredential =>
      'साइन-इन विवरण अमान्य या समाप्त हो चुके हैं।';

  @override
  String get authErrorAccountDifferent =>
      'यह ईमेल पहले से किसी अन्य साइन-इन तरीके से जुड़ा है।';

  @override
  String get authErrorInvalidEmail => 'मान्य ईमेल पता दर्ज करें।';

  @override
  String get authErrorEmailInUse => 'यह ईमेल पहले से पंजीकृत है।';

  @override
  String get authErrorWeakPassword =>
      'कम से कम 6 अक्षरों का पासवर्ड इस्तेमाल करें।';

  @override
  String get authErrorNetwork =>
      'अपना इंटरनेट कनेक्शन जाँचें और फिर प्रयास करें।';

  @override
  String get authErrorUserDisabled =>
      'यह खाता बंद कर दिया गया है। सहायता से संपर्क करें।';

  @override
  String get authErrorTooManyRequests =>
      'बहुत अधिक प्रयास हुए हैं। कुछ देर बाद फिर प्रयास करें।';

  @override
  String get authErrorSecurityCheck =>
      'सुरक्षा जाँच पूरी नहीं हो सकी। कृपया फिर प्रयास करें।';

  @override
  String get authErrorPopupBlocked =>
      'Google साइन-इन के लिए पॉप-अप की अनुमति दें और फिर प्रयास करें।';

  @override
  String get authErrorOperationDisabled =>
      'यह साइन-इन तरीका अभी उपलब्ध नहीं है।';

  @override
  String get authErrorGoogleCancelled => 'Google साइन-इन रद्द कर दिया गया।';

  @override
  String get authErrorGoogleFailed => 'अभी Google से साइन इन नहीं हो सका।';

  @override
  String get authErrorGoogleRedirecting =>
      'Google साइन-इन पर ले जाया जा रहा है...';

  @override
  String get authErrorWebConfiguration =>
      'इस वेबसाइट के लिए Google साइन-इन अभी सक्षम नहीं है।';

  @override
  String get authErrorSignInFailed =>
      'अभी साइन इन नहीं हो सका। कृपया फिर प्रयास करें।';

  @override
  String get authErrorSignUpFailed =>
      'अभी खाता नहीं बनाया जा सका। कृपया फिर प्रयास करें।';

  @override
  String get authErrorResetFailed =>
      'अभी रीसेट ईमेल नहीं भेजा जा सका। कृपया फिर प्रयास करें।';

  @override
  String get authErrorGeneric =>
      'अभी यह अनुरोध पूरा नहीं हो सका। कृपया फिर प्रयास करें।';

  @override
  String get authSignUpBeforeContinue => 'आगे बढ़ने से पहले';

  @override
  String get authSignUpNoteEmail =>
      'ऐसा ईमेल पता इस्तेमाल करें जिसे आप खोल सकें।';

  @override
  String get authSignUpNoteNext =>
      'खाता बनाने के बाद आप साइबर उदय पर आगे बढ़ सकते हैं।';

  @override
  String get authDevAccessDashboard => 'डैशबोर्ड खोलें';

  @override
  String get authDevPreview => 'डेवलपमेंट प्रीव्यू';

  @override
  String get authDemoTitle => 'डेवलपमेंट प्रीव्यू';

  @override
  String get authDemoDescription =>
      'यह अलग प्रीव्यू नमूना डेटा का उपयोग करता है और Firebase सत्र में साइन इन नहीं करता।';

  @override
  String get authDemoProtectionLabel => 'सुरक्षा स्थिति';

  @override
  String get authDemoProtectionValue => 'तैयार';

  @override
  String get authDemoThreatLabel => 'खतरे की जाँच';

  @override
  String get authDemoThreatValue => '3 नमूना परिणाम';

  @override
  String get authDemoAlertsLabel => 'अलर्ट';

  @override
  String get authDemoAlertsValue => 'कोई सक्रिय अलर्ट नहीं';

  @override
  String get authDemoExit => 'प्रीव्यू से बाहर निकलें';
}
