import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthFailure implements Exception {
  const AuthFailure(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class AuthService {
  AuthService._();

  static final AuthService instance = AuthService._();

  // These are public OAuth application identifiers, not client secrets.
  static const String _googleServerClientId =
      '1010516097616-squ252hmqem4o8fvj75mnpqa4ak7o7qp.apps.googleusercontent.com';
  static const String _iosClientId =
      '1010516097616-dc1lrqm5c15nsf5cj72k681eh3jugvpv.apps.googleusercontent.com';

  final FirebaseAuth _auth = FirebaseAuth.instance;

  GoogleSignIn get _googleSignIn {
    if (defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS) {
      return GoogleSignIn(
        clientId: _iosClientId,
        serverClientId: _googleServerClientId,
        scopes: const <String>['email', 'profile'],
      );
    }

    return GoogleSignIn(scopes: const <String>['email', 'profile']);
  }

  Stream<User?> get authStateChanges => _auth.idTokenChanges();

  User? get currentUser => _auth.currentUser;

  Future<void> initializePersistence() async {
    if (!kIsWeb) return;
    try {
      await _auth.setPersistence(Persistence.LOCAL);
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase Auth persistence setup failed: ${error.code}');
    } catch (error) {
      debugPrint(
        'Firebase Auth persistence setup failed: ${error.runtimeType}',
      );
    }

    try {
      // Firebase Auth fetches the project-managed reCAPTCHA Enterprise
      // configuration for email/password operations when it is enabled in
      // Identity Platform. The SDK owns the token lifecycle; no secret or
      // manual checkbox is required in the Flutter UI.
      await _auth.initializeRecaptchaConfig();
    } on FirebaseAuthException catch (error) {
      debugPrint('Firebase Auth security setup failed: ${error.code}');
    } catch (error) {
      debugPrint('Firebase Auth security setup failed: ${error.runtimeType}');
    }
  }

  Future<UserCredential> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        return await _signInWithGoogleWeb();
      } else {
        // FOR MOBILE: Use google_sign_in package
        final GoogleSignIn googleSignIn = _googleSignIn;
        await googleSignIn.signOut();
        final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
        if (googleUser == null) {
          throw const AuthFailure(
            'Google sign-in was cancelled.',
            code: 'google-cancelled',
          );
        }

        final GoogleSignInAuthentication googleAuth =
            await googleUser.authentication;

        if (googleAuth.idToken == null && googleAuth.accessToken == null) {
          throw const AuthFailure(
            'Google did not return usable sign-in credentials.',
            code: 'google-failed',
          );
        }

        final OAuthCredential credential = GoogleAuthProvider.credential(
          accessToken: googleAuth.accessToken,
          idToken: googleAuth.idToken,
        );

        return await _auth.signInWithCredential(credential);
      }
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseMessage(error), code: error.code);
    } on PlatformException catch (error) {
      if (error.code == 'sign_in_canceled') {
        throw const AuthFailure(
          'Google sign-in was cancelled.',
          code: 'google-cancelled',
        );
      }
      if (error.code == 'network_error') {
        throw const AuthFailure(
          'Network error during Google sign-in.',
          code: 'network-request-failed',
        );
      }
      throw const AuthFailure(
        'Unable to sign in with Google.',
        code: 'google-failed',
      );
    } catch (error) {
      if (error is AuthFailure) {
        rethrow;
      }
      debugPrint('Google Sign-In failed: ${error.runtimeType}');
      throw const AuthFailure(
        'Unable to sign in with Google.',
        code: 'google-failed',
      );
    }
  }

  Future<UserCredential> _signInWithGoogleWeb() async {
    final GoogleAuthProvider googleProvider = GoogleAuthProvider()
      ..addScope('email')
      ..addScope('profile')
      ..setCustomParameters({'prompt': 'select_account'});

    try {
      return await _auth.signInWithPopup(googleProvider);
    } on FirebaseAuthException catch (error) {
      const Set<String> redirectCodes = <String>{
        'popup-blocked',
        'operation-not-supported-in-this-environment',
      };
      if (!redirectCodes.contains(error.code)) rethrow;

      await _auth.signInWithRedirect(googleProvider);
      throw const AuthFailure(
        'Redirecting to Google sign-in.',
        code: 'google-redirect-started',
      );
    }
  }

  Future<UserCredential> login({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseMessage(error), code: error.code);
    } catch (_) {
      throw const AuthFailure(
        'Unable to sign in right now.',
        code: 'login-failed',
      );
    }
  }

  Future<UserCredential> signup({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseMessage(error), code: error.code);
    } catch (_) {
      throw const AuthFailure(
        'Unable to create your account right now.',
        code: 'signup-failed',
      );
    }
  }

  Future<void> logout() async {
    if (!kIsWeb) {
      try {
        await _googleSignIn.signOut();
      } on PlatformException catch (error) {
        debugPrint('Google sign-out cleanup failed: ${error.code}');
      }
    }
    await _auth.signOut();
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (error) {
      throw AuthFailure(_firebaseMessage(error), code: error.code);
    } catch (_) {
      throw const AuthFailure(
        'Unable to send password reset email right now.',
        code: 'reset-failed',
      );
    }
  }

  String _firebaseMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'account-exists-with-different-credential':
        return 'This email is already linked to another sign-in method.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-login-credentials':
      case 'invalid-credential':
        return 'Invalid email or password.';
      case 'email-already-in-use':
        return 'That email is already registered.';
      case 'weak-password':
        return 'Use a password with at least 6 characters.';
      case 'network-request-failed':
        return 'Unable to connect. Please check your internet connection.';
      case 'user-disabled':
        return 'This account has been disabled. Contact support for help.';
      case 'too-many-requests':
        return 'Too many attempts. Wait a moment and try again.';
      case 'captcha-check-failed':
      case 'invalid-app-credential':
      case 'missing-recaptcha-token':
      case 'captcha-required':
        return 'The security check could not be completed. Try again.';
      case 'popup-blocked':
        return 'Allow pop-ups for Google sign-in and try again.';
      case 'operation-not-allowed':
        return 'This sign-in method is not enabled in Firebase Authentication.';
      case 'popup-closed-by-user':
        return 'Google sign-in was cancelled.';
      default:
        return 'Authentication failed.';
    }
  }
}
