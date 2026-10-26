import '../../l10n/app_localizations.dart';
import '../../services/auth_service.dart';

String localizedAuthError(AppLocalizations localizations, Object error) {
  final String? code = error is AuthFailure ? error.code : null;

  return switch (code) {
    'account-exists-with-different-credential' =>
      localizations.authErrorAccountDifferent,
    'invalid-credential' => localizations.authErrorInvalidCredential,
    'invalid-email' => localizations.authErrorInvalidEmail,
    'user-not-found' ||
    'wrong-password' ||
    'invalid-login-credentials' => localizations.authErrorIncorrectCredentials,
    'email-already-in-use' => localizations.authErrorEmailInUse,
    'weak-password' => localizations.authErrorWeakPassword,
    'network-request-failed' => localizations.authErrorNetwork,
    'user-disabled' => localizations.authErrorUserDisabled,
    'too-many-requests' => localizations.authErrorTooManyRequests,
    'captcha-check-failed' ||
    'invalid-app-credential' ||
    'missing-recaptcha-token' ||
    'captcha-required' => localizations.authErrorSecurityCheck,
    'popup-blocked' => localizations.authErrorPopupBlocked,
    'operation-not-allowed' => localizations.authErrorOperationDisabled,
    'unauthorized-domain' ||
    'auth-domain-config-required' => localizations.authErrorWebConfiguration,
    'popup-closed-by-user' ||
    'google-cancelled' => localizations.authErrorGoogleCancelled,
    'google-failed' => localizations.authErrorGoogleFailed,
    'google-redirect-started' => localizations.authErrorGoogleRedirecting,
    'login-failed' => localizations.authErrorSignInFailed,
    'signup-failed' => localizations.authErrorSignUpFailed,
    'reset-failed' => localizations.authErrorResetFailed,
    _ => localizations.authErrorGeneric,
  };
}
